#include <sys/time.h>
#include <sys/types.h>
#include <unistd.h>
#include <getopt.h>
#include <assert.h>

#include "lib/mongo-c-driver/src/mongo.h"
#include "lib/mrjson/mrjson.h"
#include "lib/shelby/shelby.h"
#include "lib/cvector/cvector.h"
#include "lib/uthash/uthash.h"

#define TRUE 1
#define FALSE 0

typedef struct {
  bson_oid_t rollId;
  bson *rollBson;
  UT_hash_handle hh;
} rollFollowingBsonEntry;

static struct options {
   char *userId;
   char *userNickname;
   int postable;
   int includeFaux;
   int includeSpecial;
   int skip;
   int limit;
   char *environment;
} options;

rollFollowingBsonEntry *rollFollowings;
bson_oid_t userOid;
cvector rollOids;

struct timeval beginTime;

void printHelpText()
{
   printf("userRollFollowings usage:\n");
   printf("   -h --help            Print this help message\n");
   printf("   -u --user-id         User id\n");
   printf("   --user-nickname      User downcase nickname\n");
   printf("   -p --postable        Only return postable rolls\n");
   printf("   -i --include-faux    Include faux user rolls\n");
   printf("   --include-special    Include the user's special rolls\n");
   printf("   -s --skip            Number of non-special rolls to skip before starting to output\n");
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
         {"user-id",         required_argument, 0, 'u'},
         {"user-nickname",   required_argument, 0,   1},
         {"postable",        no_argument,       0, 'p'},
         {"include-faux",    no_argument,       0, 'i'},
         {"include-special", no_argument,       0,   0},
         {"skip",            required_argument, 0, 's'},
         {"limit",           required_argument, 0, 'l'},
         {"environment",     required_argument, 0, 'e'},
         {0, 0, 0, 0}
      };

      int option_index = 0;
      c = getopt_long(argc, argv, "hu:pis:l:e:", long_options, &option_index);

      /* Detect the end of the options. */
      if (c == -1) {
         break;
      }

      switch (c)
      {
         case 'u':
            options.userId = optarg;
            break;

         case 1:
            options.userNickname = optarg;
            break;

         case 'p':
            options.postable = TRUE;
            break;

         case 'i':
            options.includeFaux = TRUE;
            break;

         case 0:
            options.includeSpecial = TRUE;
            break;

         case 's':
            options.skip = atoi(optarg);
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

   if (strcmp(options.userId, "") == 0 && strcmp(options.userNickname, "") == 0) {
      printf("Specifying user id or nickname is required.\n");
      printHelpText();
      exit(1);
   }
}

void setDefaultOptions()
{
   options.userId = "";
   options.userNickname = "";
   options.postable = FALSE;
   options.includeFaux = FALSE;
   options.includeSpecial = FALSE;
   options.skip = 0;
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

int getRollFollowedAtTime(sobContext sob, bson *roll)
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

   return sobGetOidGenerationTimeSinceEpoch(&rollFollowing, NULL);
}

void printJsonRoll(sobContext sob, mrjsonContext context, bson *roll)
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
                                     SOB_CREATOR,
                                     roll,
                                     SOB_ROLL_CREATOR_ID,
                                     &rollCreator);

   if (status) {
      sobPrintAttributeWithKeyOverride(context,
                                       rollCreator,
                                       SOB_CREATOR_NICKNAME,
                                       "creator_nickname");

      sobPrintAttributeWithKeyOverride(context,
                                       rollCreator,
                                       SOB_CREATOR_NAME,
                                       "creator_name");

      sobPrintStringToBoolAttributeWithKeyOverride(context,
                                                   rollCreator,
                                                   SOB_CREATOR_AVATAR_FILE_NAME,
                                                   "creator_has_shelby_avatar");

      sobPrintAttributeWithKeyOverride(context,
                                       rollCreator,
                                       SOB_CREATOR_AVATAR_UPDATED_AT,
                                       "creator_avatar_updated_at");

      sobPrintAttributeWithKeyOverride(context,
                                       rollCreator,
                                       SOB_CREATOR_USER_IMAGE_ORIGINAL,
                                       "creator_image_original");

      sobPrintAttributeWithKeyOverride(context,
                                       rollCreator,
                                       SOB_CREATOR_USER_IMAGE,
                                       "creator_image");

      sobPrintSubobjectArrayWithKey(sob,
                                    context,
                                    rollCreator,
                                    SOB_CREATOR_AUTHENTICATIONS,
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

   int followedAtTime = getRollFollowedAtTime(sob, roll);
   mrjsonIntAttribute(context, "followed_at", followedAtTime);

   mrjsonEndObject(context);
}

int printJsonOutput(sobContext sob)
{
   // get rolls
   cvector rolls = cvectorAlloc(sizeof(bson *));
   sobGetBsonVector(sob, SOB_ROLL, rolls);

   // put the rolls into a hash for faster access
   rollFollowings = NULL;
   for (int i = 0; i <  cvectorCount(rolls); i++) {
      bson *roll = *(bson **)cvectorGetElement(rolls, i);
      rollFollowingBsonEntry *toInsert = (rollFollowingBsonEntry *)malloc(sizeof(rollFollowingBsonEntry));
      if (!toInsert) {
        return FALSE;
      }
      memset(toInsert, 0, sizeof(rollFollowingBsonEntry));

      bson_oid_t rollOid;
      sobBsonOidField(SOB_ROLL, SOB_ROLL_ID, roll, &rollOid);
      toInsert->rollId = rollOid;
      toInsert->rollBson = roll;
      HASH_ADD(hh, rollFollowings, rollId, sizeof(bson_oid_t), toInsert);
   }

   // allocate context; match Ruby API "status" and "result" response syntax
   sobEnvironment environment = sobGetEnvironment(sob);
   mrjsonContext context = mrjsonAllocContext(environment != SOB_PRODUCTION && environment != SOB_STAGING);
   mrjsonStartResponse(context);
   mrjsonIntAttribute(context, "status", 200);
   mrjsonStartArray(context, "result");

   if (options.includeSpecial) {
      bson *userBson;

      int userStatus = sobGetBsonByOid(sob, SOB_USER, userOid, &userBson);

      if (userStatus) {
         int rollStatus;

         // first 2 rolls are always the user public roll and the user watch later roll
         bson_oid_t userPublicRollId;
         rollStatus = sobBsonOidField(SOB_USER,
                                      SOB_USER_PUBLIC_ROLL_ID,
                                      userBson,
                                      &userPublicRollId);
         if (rollStatus) {
            rollFollowingBsonEntry *foundRollFollowing = NULL;
            HASH_FIND(hh, rollFollowings, &userPublicRollId, sizeof(bson_oid_t), foundRollFollowing);
            if (foundRollFollowing) {
               printJsonRoll(sob, context, foundRollFollowing->rollBson);
            }
         }

         bson_oid_t userWatchLaterRollId;
         rollStatus = sobBsonOidField(SOB_USER,
                                      SOB_USER_WATCH_LATER_ROLL_ID,
                                      userBson,
                                      &userWatchLaterRollId);
         if (rollStatus) {
            rollFollowingBsonEntry *foundRollFollowing = NULL;
            HASH_FIND(hh, rollFollowings, &userWatchLaterRollId, sizeof(bson_oid_t), foundRollFollowing);
            if (foundRollFollowing) {
               printJsonRoll(sob, context, foundRollFollowing->rollBson);
            }
         }
      }
   }

   int rollCount = cvectorCount(rollOids);
   int startIndex = rollCount - options.skip - 1;
   int finishIndex;

   if (options.limit > 0) {
    finishIndex = startIndex - (options.limit - 1);
   } else {
    finishIndex = 0;
   }

   if (finishIndex < 0) {
    finishIndex = 0;
   }

   for (int i = startIndex; i >= finishIndex; i--) {
      bson_oid_t *rollOid = (bson_oid_t *)cvectorGetElement(rollOids, i);
      rollFollowingBsonEntry *foundRollFollowing = NULL;
      char rollId [25];
      bson_oid_to_string(rollOid, rollId);
      HASH_FIND(hh, rollFollowings, rollOid, sizeof(bson_oid_t), foundRollFollowing);
      if (foundRollFollowing) {
         bson *roll = foundRollFollowing->rollBson;
         if (shouldPrintRegularRoll(sob, roll)) {
            printJsonRoll(sob, context, roll);
         }
      }
   }

   mrjsonEndArray(context);

   mrjsonIntAttribute(context, "cApiTimeMs", timeSinceMS(beginTime));
   mrjsonEndResponse(context);

   // until now the output has just been buffered. now we dump it all out.
   mrjsonPrintContext(context);

   // not a big deal to prevent memory leaks until we have persistent FastCGI, but this is easy
   mrjsonFreeContext(context);

   return TRUE;
}

/*
 * TODO: This function needs error checking, since some sob calls can fail...
 */
int loadData(sobContext sob)
{
   rollOids = cvectorAlloc(sizeof(bson_oid_t));
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
                                             options.userNickname);
   }

   cvectorAddElement(userOids, &userOid);
   static sobField userFields[] = {
      SOB_USER_NICKNAME,
      SOB_USER_NAME,
      SOB_USER_AVATAR_FILE_NAME,
      SOB_USER_AVATAR_UPDATED_AT,
      SOB_USER_USER_IMAGE_ORIGINAL,
      SOB_USER_USER_IMAGE,
      SOB_USER_AUTHENTICATIONS,
      SOB_USER_ROLL_FOLLOWINGS,
      SOB_USER_UPVOTED_ROLL_ID,
      SOB_USER_PUBLIC_ROLL_ID,
      SOB_USER_WATCH_LATER_ROLL_ID
   };
   sobLoadAllByIdSpecifyFields(sob,
                               SOB_USER,
                               userFields,
                               sizeof(userFields) / sizeof(sobField),
                               userOids);

   sobGetOidVectorFromObjectArrayField(sob, SOB_USER, SOB_USER_ROLL_FOLLOWINGS, SOB_ROLL_FOLLOWING_ROLL_ID, rollOids);

   static sobField rollFields[] = {
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
      SOB_ROLL_DISCUSSION_ROLL_PARTICIPANTS,
      SOB_ROLL_FOLLOWING_USERS,
      SOB_ROLL_SUBDOMAIN,
      SOB_ROLL_SUBDOMAIN_ACTIVE,
      SOB_ROLL_CREATOR_THUMBNAIL_URL
   };
   sobLoadAllByIdSpecifyFields(sob,
                               SOB_ROLL,
                               rollFields,
                               sizeof(rollFields) / sizeof(sobField),
                               rollOids);

   sobGetOidVectorFromObjectField(sob, SOB_ROLL, SOB_ROLL_CREATOR_ID, creatorOids);
   static sobField creatorFields[] = {
      SOB_CREATOR_NICKNAME,
      SOB_CREATOR_NAME,
      SOB_CREATOR_AVATAR_FILE_NAME,
      SOB_CREATOR_AVATAR_UPDATED_AT,
      SOB_CREATOR_USER_IMAGE_ORIGINAL,
      SOB_CREATOR_USER_IMAGE,
      SOB_CREATOR_AUTHENTICATIONS
   };
   sobLoadAllByIdSpecifyFields(sob,
                               SOB_CREATOR,
                               creatorFields,
                               sizeof(creatorFields) / sizeof(sobField),
                               creatorOids);

   return TRUE;
}

int main(int argc, char **argv)
{
   rollFollowingBsonEntry *p, *tmp = NULL;

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


   if (!printJsonOutput(sob)) {
      status = 3;
      goto cleanup;
   }


cleanup:

   HASH_ITER(hh, rollFollowings, p, tmp) {
      HASH_DEL(rollFollowings, p);
      free(p);
   }

   sobFreeContext(sob);

   return status;
}
