#include <sys/time.h>
#include <sys/types.h>
#include <unistd.h>
#include <getopt.h>
#include <assert.h>

#include "lib/mongo-c-driver/src/mongo.h"
#include "lib/mrjson/mrjson.h"
#include "lib/shelby/shelby.h"
#include "lib/cvector/cvector.h"

#define TRUE 1
#define FALSE 0

static struct options {
   char* user;
   char* userId;
   int postable;
   int includeFaux;
   int includeSpecial;
   int limit;
   char *environment;
} options;

bson_oid_t userOid;

typedef struct rollSortable {
   bson *roll;
   bson_timestamp_t followedAt;
} rollSortable;

struct timeval beginTime;

void printHelpText()
{
   printf("userRollFollowings usage:\n");
   printf("   -h --help            Print this help message\n");
   printf("   -u --user            User downcase nickname\n");
   printf("   -d --user-id         User id\n");
   printf("   -p --postable        Only return postable rolls\n");
   printf("   -i --include-faux    Include faux user rolls\n");
   printf("   -s --include-special Include the user's special rolls\n");
   printf("   -l --limit           Maximum number of non-special rolls to return\n");
   printf("   -e --environment     Specify environment: production, staging, test, or development\n");
}

void parseUserOptions(int argc, char **argv)
{
   int c;

   while (1) {
      static struct option long_options[] =
      {
         {"help",            no_argument,       0, 'h'},
         {"user",            optional_argument, 0, 'u'},
         {"user-id",         optional_argument, 0, 'd'},
         {"postable",        no_argument,       0, 'p'},
         {"include-faux",    no_argument,       0, 'i'},
         {"include-special", no_argument,       0, 's'},
         {"limit",           optional_argument, 0, 'l'},
         {"environment",     required_argument, 0, 'e'},
         {0, 0, 0, 0}
      };

      int option_index = 0;
      c = getopt_long(argc, argv, "hu:d:pisl:e:", long_options, &option_index);

      /* Detect the end of the options. */
      if (c == -1) {
         break;
      }

      switch (c)
      {
         case 'u':
            options.user = optarg;
            break;

         case 'd':
            options.userId = optarg;
            break;

         case 'p':
            options.postable = TRUE;
            break;

         case 'i':
            options.includeFaux = TRUE;
            break;

         case 's':
            options.includeSpecial = TRUE;
            break;

         case 'l':
            options.limit = atoi(optarg);

         case 'e':
            options.environment = optarg;
            break;

         case 'h':
         case '?':
         default:
            printHelpText();
            exit(1);
      }
   }

   if (strcmp(options.environment, "") == 0) {
      printf("Specifying -e or --environment is required.\n");
      printHelpText();
      exit(1);
   }

   if (strcmp(options.user, "") == 0 && strcmp(options.userId, "") == 0) {
      printf("Specifying user id or nickname is required.\n");
      printHelpText();
      exit(1);
   }
}

void setDefaultOptions()
{
   options.user = "";
   options.userId = "";
   options.postable = FALSE;
   options.includeFaux = FALSE;
   options.includeSpecial = FALSE;
   options.limit = 0;
   options.environment = "";
}

unsigned int timeSinceMS(struct timeval begin)
{
   struct timeval currentTime;
   gettimeofday(&currentTime, NULL);

   struct timeval difference;
   timersub(&currentTime, &begin, &difference);

   return difference.tv_sec * 1000 + (difference.tv_usec / 1000);
}

int rollPostable(sobContext sob, bson_oid_t rollOid, bson *roll)
{
   bson_oid_t rollCreatorOid;
   sobBsonOidField(SOB_ROLL, SOB_ROLL_CREATOR_ID, roll, &rollCreatorOid);

   if (sobBsonOidEqual(rollCreatorOid, userOid)) {
      return TRUE;
   } else if (!sobBsonBoolField(sob, SOB_ROLL, SOB_ROLL_COLLABORATIVE, rollOid)) {
      return FALSE;
   } else if (sobBsonBoolField(sob, SOB_ROLL, SOB_ROLL_PUBLIC, rollOid)) {
      return TRUE;
   } else if (sobOidArrayFieldContainsOid(sob, SOB_ROLL_FOLLOWING_USERS, SOB_FOLLOWING_USER_USER_ID, roll, userOid)) {
      return TRUE;
   }

   return FALSE;
}

int shouldPrintRegularRoll(sobContext sob, bson *roll)
{
   bson_oid_t rollOid;
   sobBsonOidField(SOB_ROLL, SOB_ROLL_ID, roll, &rollOid);

   if (options.postable && !rollPostable(sob, rollOid, roll)) {
      return FALSE;
   }

   int rollType = 10;
   int status = sobBsonIntField(sob, SOB_ROLL, SOB_ROLL_ROLL_TYPE, rollOid, &rollType);
   if (!status) {
      /*
       * this is supposed to be the default; rails version was dumb about this...
       * basically, rails roll model says 10 is the default. but following API was
       * only querying for rolls with roll_type *NOT* 10 or 11. so if roll_type was missing
       * in the DB, it would still get printed out.
       */
      rollType = 10;
   }

   // 10 is generic special roll a type we don't display anymore
   if (10 == rollType) {
      return FALSE;
   }

   // unless the option is explicitly set to include them, we don't display type 11 special_public (faux user) rolls
   if (!options.includeFaux && 11 == rollType) {
      return FALSE;
   }

   // we don't use the upvoted roll anymore
   if (sobBsonOidFieldEqual(sob, SOB_USER, SOB_USER_UPVOTED_ROLL_ID, userOid, rollOid)) {
      return FALSE;
   }

   // these get printed out by the calling function first, and are ordered / treated specially
   if (sobBsonOidFieldEqual(sob, SOB_USER, SOB_USER_PUBLIC_ROLL_ID, userOid, rollOid) ||
       sobBsonOidFieldEqual(sob, SOB_USER, SOB_USER_WATCH_LATER_ROLL_ID, userOid, rollOid))
   {
      return FALSE;
   }

   return TRUE;
}

void printJsonAuthentication(sobContext sob, mrjsonContext context, bson *authentication)
{
   static sobField authenticationAttributes[] = {
      SOB_AUTHENTICATION_PROVIDER,
      SOB_AUTHENTICATION_UID,
      SOB_AUTHENTICATION_NICKNAME,
      SOB_AUTHENTICATION_NAME
   };

   sobPrintAttributes(context,
                      authentication,
                      authenticationAttributes,
                      sizeof(authenticationAttributes) / sizeof(sobField));

}

void printJsonRoll(sobContext sob, mrjsonContext context, bson *roll, unsigned int followedAtTime)
{
   mrjsonStartNamelessObject(context);

   static sobField rollAttributes[] = {
      SOB_ROLL_ID,
      SOB_ROLL_COLLABORATIVE,
      SOB_ROLL_PUBLIC,
      SOB_ROLL_CREATOR_ID,
      SOB_ROLL_ORIGIN_NETWORK,
      SOB_ROLL_GENIUS,
      SOB_ROLL_FRAME_COUNT,
      SOB_ROLL_FIRST_FRAME_THUMBNAIL_URL,
      SOB_ROLL_HEADER_IMAGE_FILE_NAME,
      SOB_ROLL_TITLE,
      SOB_ROLL_ROLL_TYPE,
      SOB_ROLL_DISCUSSION_ROLL_PARTICIPANTS
   };

   sobPrintAttributes(context,
                      roll,
                      rollAttributes,
                      sizeof(rollAttributes) / sizeof(sobField));

   sobPrintFieldIfBoolField(context,
                            roll,
                            SOB_ROLL_SUBDOMAIN,
                            SOB_ROLL_SUBDOMAIN_ACTIVE);

   bson *rollCreator;
   int status = sobGetBsonByOidField(sob,
                                     SOB_USER,
                                     roll,
                                     SOB_ROLL_CREATOR_ID,
                                     &rollCreator);

   if (status) {
      sobPrintAttributeWithKeyOverride(context,
                                       rollCreator,
                                       SOB_USER_NICKNAME,
                                       "creator_nickname");

      sobPrintAttributeWithKeyOverride(context,
                                       rollCreator,
                                       SOB_USER_NAME,
                                       "creator_name");

      sobPrintStringToBoolAttributeWithKeyOverride(context,
                                                   rollCreator,
                                                   SOB_USER_AVATAR_FILE_NAME,
                                                   "creator_has_shelby_avatar");

      sobPrintAttributeWithKeyOverride(context,
                                       rollCreator,
                                       SOB_USER_AVATAR_UPDATED_AT,
                                       "creator_avatar_updated_at");

      sobPrintAttributeWithKeyOverride(context,
                                       rollCreator,
                                       SOB_USER_USER_IMAGE_ORIGINAL,
                                       "creator_image_original");

      sobPrintAttributeWithKeyOverride(context,
                                       rollCreator,
                                       SOB_USER_USER_IMAGE,
                                       "creator_image");

      sobPrintSubobjectArrayWithKey(sob,
                                    context,
                                    rollCreator,
                                    SOB_USER_AUTHENTICATIONS,
                                    "creator_authentications",
                                    &printJsonAuthentication);
   }

   sobPrintAttributeWithKeyOverride(context,
                                    roll,
                                    SOB_ROLL_CREATOR_THUMBNAIL_URL,
                                    "thumbnail_url");

   sobPrintArrayAttributeCountWithKey(context,
                                      roll,
                                      SOB_ROLL_FOLLOWING_USERS,
                                      "following_user_count");

   mrjsonIntAttribute(context, "followed_at", followedAtTime);

   mrjsonEndObject(context);
}

int getRollFollowedAtTime(sobContext sob, bson *roll, bson_timestamp_t *ts)
{
   bson_oid_t rollOid;
   sobBsonOidField(SOB_ROLL, SOB_ROLL_ID, roll, &rollOid);

   bson rollFollowing;
   sobGetBsonForArrayObjectWithOidField(sob,
                                        SOB_USER,
                                        userOid,
                                        SOB_USER_ROLL_FOLLOWINGS,
                                        SOB_ROLL_FOLLOWING_ROLL_ID,
                                        rollOid,
                                        &rollFollowing);

   return sobGetOidGenerationTimeSinceEpoch(&rollFollowing, ts);
}

int rollSortByFollowedAt(void *one, void *two)
{
   rollSortable *rsOne = (rollSortable *)one;
   rollSortable *rsTwo = (rollSortable *)two;

   if ((rsOne->followedAt.t == rsTwo->followedAt.t) &&
       (rsOne->followedAt.i == rsTwo->followedAt.i)) {
      return 0;
   } else if ((rsOne->followedAt.t < rsTwo->followedAt.t) ||
              (rsOne->followedAt.t == rsTwo->followedAt.t &&
               rsOne->followedAt.i < rsTwo->followedAt.i)) {
      return 1;
   } else {
      return -1;
   }
}

void printJsonOutput(sobContext sob)
{
   // get rolls
   cvector rolls = cvectorAlloc(sizeof(bson *));
   sobGetBsonVector(sob, SOB_ROLL, rolls);

   // allocate context; match Ruby API "status" and "result" response syntax
   sobEnvironment environment = sobGetEnvironment(sob);
   mrjsonContext context = mrjsonAllocContext(environment != SOB_PRODUCTION && environment != SOB_STAGING);
   mrjsonStartResponse(context);
   mrjsonIntAttribute(context, "status", 200);
   mrjsonStartArray(context, "result");

   if (options.includeSpecial) {
      bson *userBson;
      bson *publicRoll;
      bson *watchLaterRoll;

      int publicRollStatus = FALSE;
      int watchLaterRollStatus = FALSE;

      int userStatus = sobGetBsonByOid(sob, SOB_USER, userOid, &userBson);

      if (userStatus) {
         publicRollStatus = sobGetBsonByOidField(sob,
                                                 SOB_ROLL,
                                                 userBson,
                                                 SOB_USER_PUBLIC_ROLL_ID,
                                                 &publicRoll);

         watchLaterRollStatus = sobGetBsonByOidField(sob,
                                                     SOB_ROLL,
                                                     userBson,
                                                     SOB_USER_WATCH_LATER_ROLL_ID,
                                                     &watchLaterRoll);
      }

      // first 2 rolls are always the user public roll and the user watch later roll
      if (publicRollStatus) {
         printJsonRoll(sob, context, publicRoll, getRollFollowedAtTime(sob, publicRoll, NULL));
      }

      if (watchLaterRollStatus) {
         printJsonRoll(sob, context, watchLaterRoll, getRollFollowedAtTime(sob, watchLaterRoll, NULL));
      }
   }

   cvector rollSortVec = cvectorAlloc(sizeof(rollSortable));

   // create sortable vector of rolls we should print
   for (int i = 0; i < cvectorCount(rolls); i++) {

      bson *roll = *(bson **)cvectorGetElement(rolls, i);

      if (shouldPrintRegularRoll(sob, roll)) {

         rollSortable *rs = malloc(sizeof(rollSortable));
         rs->roll = roll;
         getRollFollowedAtTime(sob, roll, &(rs->followedAt));

         cvectorAddElement(rollSortVec, rs);
      }
   }

   cvectorSort(rollSortVec, &rollSortByFollowedAt);

   int rollCount = cvectorCount(rollSortVec);
   int numRollsToPrint;

   if (options.limit > 0) {
    numRollsToPrint = options.limit < rollCount ? options.limit : rollCount;
   } else {
    numRollsToPrint = rollCount;
   }

   for (int i = 0; i < numRollsToPrint; i++) {
      rollSortable *rs = (rollSortable *)cvectorGetElement(rollSortVec, i);
      printJsonRoll(sob, context, rs->roll, rs->followedAt.t);
   }

   mrjsonEndArray(context);

   mrjsonIntAttribute(context, "cApiTimeMs", timeSinceMS(beginTime));
   mrjsonEndResponse(context);

   // until now the output has just been buffered. now we dump it all out.
   mrjsonPrintContext(context);

   // not a big deal to prevent memory leaks until we have persistent FastCGI, but this is easy
   mrjsonFreeContext(context);
}

/*
 * TODO: This function needs error checking, since some sob calls can fail...
 */
int loadData(sobContext sob)
{
   cvector rollOids = cvectorAlloc(sizeof(bson_oid_t));
   cvector userOids = cvectorAlloc(sizeof(bson_oid_t));
   cvector creatorOids = cvectorAlloc(sizeof(bson_oid_t));

   if (strcmp(options.userId, "") != 0) {
      // if a user id was passed as a parameter, use that
      bson_oid_from_string(&userOid, options.userId);
   } else {
      // otherwise lookup the user by the nickname supplied and get their id
      userOid = sobGetUniqueOidByStringField(sob,
                                             SOB_USER,
                                             SOB_USER_DOWNCASE_NICKNAME,
                                             options.user);
   }

   cvectorAddElement(userOids, &userOid);
   sobLoadAllById(sob, SOB_USER, userOids);

   sobGetOidVectorFromObjectArrayField(sob, SOB_USER, SOB_USER_ROLL_FOLLOWINGS, SOB_ROLL_FOLLOWING_ROLL_ID, rollOids);
   sobLoadAllById(sob, SOB_ROLL, rollOids);

   sobGetOidVectorFromObjectField(sob, SOB_ROLL, SOB_ROLL_CREATOR_ID, creatorOids);
   sobLoadAllById(sob, SOB_USER, creatorOids);

   return TRUE;
}

int main(int argc, char **argv)
{
   gettimeofday(&beginTime, NULL);

   int status = 0;

   setDefaultOptions();
   parseUserOptions(argc, argv);

   sobEnvironment env = sobEnvironmentFromString(options.environment);
   sobContext sob = sobAllocContext(env);

   if (!loadData(sob)) {
      status = 2;
      goto cleanup;
   }

   printJsonOutput(sob);

cleanup:
   sobFreeContext(sob);

   return status;
}
