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
   char* rollString;
   bson_oid_t roll;

   char* userString;
   bson_oid_t user;

   int limit;
   int skip;
   char *environment;

   char *sinceIdString;

   int permissionGranted;
} options;

struct timeval beginTime;

void printHelpText()
{
   printf("frameIndex usage:\n");
   printf("   -h --help                 Print this help message\n");
   printf("   -u --user                 String representation of user OID\n");
   printf("   -r --roll                 String representation of roll OID\n");
   printf("   -l --limit                Limit to this number of frames\n");
   printf("   -s --skip                 Skip this number of frames\n");
   printf("   -i --sinceid              Frames since this one (inclusive)\n");
   printf("   -p --permissionGranted    Return the frames without checking Roll permission (takes no argument)\n");
   printf("   -e --environment          Specify environment: production, staging, test, or development\n");
}

void parseUserOptions(int argc, char **argv)
{
   int c;

   while (1) {
      static struct option long_options[] =
      {
         {"help",               no_argument,       0, 'h'},
         {"user",               required_argument, 0, 'u'},
         {"roll",               required_argument, 0, 'r'},
         {"limit",              required_argument, 0, 'l'},
         {"skip",               required_argument, 0, 's'},
         {"sinceid",            required_argument, 0, 'i'},
         {"permissionGranted",  no_argument,       0, 'p'},
         {"environment",        required_argument, 0, 'e'},
         {0, 0, 0, 0}
      };

      int option_index = 0;
      c = getopt_long(argc, argv, "hr:l:s:e:u:i:p", long_options, &option_index);

      /* Detect the end of the options. */
      if (c == -1) {
         break;
      }

      switch (c)
      {
         case 'u':
            options.userString = optarg;
            bson_oid_from_string(&options.user, optarg);
            break;

         case 'r':
            options.rollString = optarg;
            bson_oid_from_string(&options.roll, optarg);
            break;

         case 'l':
            options.limit = atoi(optarg);
            break;

         case 's':
            options.skip = atoi(optarg);
            break;

         case 'e':
            options.environment = optarg;
            break;

         case 'i':
            options.sinceIdString = optarg;
            break;

         case 'p':
            options.permissionGranted = TRUE;
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

   if (strcmp(options.rollString, "") == 0 &&
       strcmp(options.userString, "") == 0) {
      printf("Must specify either -u/--user or -r/--roll.\n");
      printHelpText();
      exit(1);
   }
}

void setDefaultOptions()
{
   options.rollString = "";
   options.userString = "";
   options.limit = 20;
   options.skip = 0;
   options.environment = "";
   options.sinceIdString = "";
   options.permissionGranted = FALSE;
}

unsigned int timeSinceMS(struct timeval begin)
{
   struct timeval currentTime;
   gettimeofday(&currentTime, NULL);

   struct timeval difference;
   timersub(&currentTime, &begin, &difference);

   return difference.tv_sec * 1000 + (difference.tv_usec / 1000);
}

void printJsonMessage(sobContext sob, mrjsonContext context, bson *message)
{
   static sobField messageAttributes[] = {
      SOB_MESSAGE_ID,
      SOB_MESSAGE_NICKNAME,
      SOB_MESSAGE_REALNAME,
      SOB_MESSAGE_USER_IMAGE_URL,
      SOB_MESSAGE_TEXT,
      SOB_MESSAGE_ORIGIN_NETWORK,
      SOB_MESSAGE_ORIGIN_ID,
      SOB_MESSAGE_ORIGIN_USER_ID,
      SOB_MESSAGE_USER_ID,
      SOB_MESSAGE_USER_HAS_SHELBY_AVATAR,
      SOB_MESSAGE_PUBLIC
   };

   sobPrintAttributes(context,
                      message,
                      messageAttributes,
                      sizeof(messageAttributes) / sizeof(sobField));

   sobPrintOidConciseTimeAgoAttribute(context,
                                      message,
                                      SOB_MESSAGE_ID,
                                      "created_at");
}

void printJsonConversation(sobContext sob, mrjsonContext context, bson *conversation)
{
   static sobField conversationAttributes[] = {
      SOB_CONVERSATION_ID,
      SOB_CONVERSATION_PUBLIC
   };

   sobPrintAttributes(context,
                      conversation,
                      conversationAttributes,
                      sizeof(conversationAttributes) / sizeof(sobField));

   sobPrintSubobjectArray(sob,
                          context,
                          conversation,
                          SOB_CONVERSATION_MESSAGES,
                          &printJsonMessage);
}

void printJsonRecommendation(sobContext sob, mrjsonContext context, bson *recommendation) {
   static sobField recommendationAttributes[] = {
      SOB_RECOMMENDATION_RECOMMENDED_VIDEO_ID,
      SOB_RECOMMENDATION_SCORE
   };

   sobPrintAttributes(context,
                      recommendation,
                      recommendationAttributes,
                      sizeof(recommendationAttributes) / sizeof(sobField));
}

void printJsonVideo(sobContext sob, mrjsonContext context, bson *video)
{
   static sobField videoAttributes[] = {
      SOB_VIDEO_ID,
      SOB_VIDEO_PROVIDER_NAME,
      SOB_VIDEO_PROVIDER_ID,
      SOB_VIDEO_TITLE,
      SOB_VIDEO_DESCRIPTION,
      SOB_VIDEO_DURATION,
      SOB_VIDEO_AUTHOR,
      SOB_VIDEO_THUMBNAIL_URL,
      SOB_VIDEO_SOURCE_URL,
      SOB_VIDEO_EMBED_URL,
      SOB_VIDEO_VIEW_COUNT,
      SOB_VIDEO_LIKE_COUNT,
      SOB_VIDEO_TRACKED_LIKER_COUNT,
      SOB_VIDEO_TAGS,
      SOB_VIDEO_CATEGORIES,
      SOB_VIDEO_FIRST_UNPLAYABLE_AT,
      SOB_VIDEO_LAST_UNPLAYABLE_AT
   };
   bson_oid_t videoOid;

   sobBsonOidField(SOB_VIDEO,
                   SOB_VIDEO_ID,
                   video,
                   &videoOid);

   char videoIdString[25];

   bson_oid_to_string(&videoOid, videoIdString);
   sobLog("Printing JSON for video: %s", videoIdString);

   sobLog("Printing video standard fields");

   sobPrintAttributes(context,
                      video,
                      videoAttributes,
                      sizeof(videoAttributes) / sizeof(sobField));

   sobLog("Printing video recommendations array");

   sobPrintSubobjectArray(sob,
                          context,
                          video,
                          SOB_VIDEO_RECS,
                          &printJsonRecommendation);
}

void printJsonRoll(sobContext sob, mrjsonContext context, bson *roll)
{
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

   sobPrintAttributeWithKeyOverride(context,
                                    roll,
                                    SOB_ROLL_CREATOR_THUMBNAIL_URL,
                                    "thumbnail_url");

   sobPrintFieldIfBoolField(context,
                            roll,
                            SOB_ROLL_SUBDOMAIN,
                            SOB_ROLL_SUBDOMAIN_ACTIVE);

}

void printJsonAuthentication(sobContext sob, mrjsonContext context, bson *authentication)
{
   static sobField authenticationAttributes[] = {
      SOB_AUTHENTICATION_UID,
      SOB_AUTHENTICATION_PROVIDER,
      SOB_AUTHENTICATION_NICKNAME
   };

   sobPrintAttributes(context,
                      authentication,
                      authenticationAttributes,
                      sizeof(authenticationAttributes) / sizeof(sobField));

}

void printJsonUser(sobContext sob, mrjsonContext context, bson *user)
{
   static sobField userAttributes[] = {
      SOB_USER_ID,
      SOB_USER_NAME,
      SOB_USER_NICKNAME,
      SOB_USER_USER_IMAGE_ORIGINAL,
      SOB_USER_USER_IMAGE,
      SOB_USER_USER_TYPE,
      SOB_USER_PUBLIC_ROLL_ID,
   };

   bson_oid_t userOid;

   sobBsonOidField(SOB_USER,
                   SOB_USER_ID,
                   user,
                   &userOid);

   char userIdString[25];

   bson_oid_to_string(&userOid, userIdString);
   sobLog("Printing JSON for user: %s", userIdString);

   sobLog("Printing user has_shelby_avatar field");

   sobPrintStringToBoolAttributeWithKeyOverride(context,
                                                user,
                                                SOB_USER_AVATAR_FILE_NAME,
                                                "has_shelby_avatar");

   sobLog("Printing user standard fields");

   sobPrintAttributes(context,
                      user,
                      userAttributes,
                      sizeof(userAttributes) / sizeof(sobField));

   sobLog("Printing user authentications array");

   sobPrintSubobjectArray(sob,
                          context,
                          user,
                          SOB_USER_AUTHENTICATIONS,
                          &printJsonAuthentication);
}

void printJsonOriginator(sobContext sob, mrjsonContext context, bson *originator)
{
   static sobField originatorAttributes[] = {
      SOB_USER_ID,
      SOB_USER_NAME,
      SOB_USER_NICKNAME,
      SOB_USER_USER_TYPE
   };
   bson_oid_t userOid;

   sobBsonOidField(SOB_USER,
                   SOB_USER_ID,
                   originator,
                   &userOid);

   char userIdString[25];

   bson_oid_to_string(&userOid, userIdString);
   sobLog("Printing JSON for user: %s", userIdString);

   sobLog("Printing user standard fields");

   sobPrintAttributes(context,
                      originator,
                      originatorAttributes,
                      sizeof(originatorAttributes) / sizeof(sobField));

}

/*
 * There are some attributes in the Ruby API that this C API is not printing
 * (because they seem outdated / unused):
 *
 *  - frame_ancestors
 *  - frame_children
 *  - timestamp
 *  - upvote_users
 *
 */
void printJsonFrame(sobContext sob, mrjsonContext context, bson *frame)
{
   static sobField frameAttributes[] = {
      SOB_FRAME_ID,
      SOB_FRAME_SCORE,
      SOB_FRAME_VIEW_COUNT,
      SOB_FRAME_CREATOR_ID,
      SOB_FRAME_ANONYMOUS_CREATOR_NICKNAME,
      SOB_FRAME_CONVERSATION_ID,
      SOB_FRAME_ROLL_ID,
      SOB_FRAME_VIDEO_ID,
      SOB_FRAME_UPVOTERS,
      SOB_FRAME_LIKE_COUNT,
      SOB_FRAME_FRAME_TYPE
   };
   bson_oid_t frameOid;
   bson_oid_t originatorFrameOid;
   bson *originatorFrame;
   bson *originator;

   sobBsonOidField(SOB_FRAME,
                   SOB_FRAME_ID,
                   frame,
                   &frameOid);

   char frameIdString[25];

   bson_oid_to_string(&frameOid, frameIdString);
   sobLog("Printing JSON for frame: %s", frameIdString);

   sobLog("Printing frame standard fields");

   sobPrintAttributes(context,
                      frame,
                      frameAttributes,
                      sizeof(frameAttributes) / sizeof(sobField));

   sobLog("Checking if frame has an originator frame");
   int status = sobBsonOidArrayFieldLast(SOB_FRAME,
                                         SOB_FRAME_FRAME_ANCESTORS,
                                         frame,
                                         &originatorFrameOid);

   // print info about the originating user if the current frame has an ancestor
   if (status) {
      sobGetBsonByOid(sob,
                      SOB_ANCESTOR_FRAME,
                      originatorFrameOid,
                      &originatorFrame);

      sobLog("Checking if originator frame has a creator");
      status = sobGetBsonByOidField(sob,
                                        SOB_USER,
                                        originatorFrame,
                                        SOB_ANCESTOR_FRAME_CREATOR_ID,
                                        &originator);

      if (status) {
         sobLog("Printing frame originator_id field");
         sobPrintAttributeWithKeyOverride(context,
                                          originator,
                                          SOB_USER_ID,
                                          "originator_id");

         sobLog("Printing frame originator field");
         sobPrintSubobjectByOid(sob,
                                context,
                                originatorFrame,
                                SOB_ANCESTOR_FRAME_CREATOR_ID,
                                SOB_USER,
                                "originator",
                                &printJsonOriginator);
      } else {
         mrjsonNullAttribute(context, "originator_id");
         mrjsonNullAttribute(context, "originator");
      }
   } else {
      mrjsonNullAttribute(context, "originator_id");
      mrjsonNullAttribute(context, "originator");
   }

   sobLog("Printing frame created_at field");

   sobPrintOidConciseTimeAgoAttribute(context,
                                      frame,
                                      SOB_FRAME_ID,
                                      "created_at");

   sobLog("Printing frame creator field");

   sobPrintSubobjectByOid(sob,
                          context,
                          frame,
                          SOB_FRAME_CREATOR_ID,
                          SOB_USER,
                          "creator",
                          &printJsonUser);

   sobLog("Printing frame roll field");

   sobPrintSubobjectByOid(sob,
                          context,
                          frame,
                          SOB_FRAME_ROLL_ID,
                          SOB_ROLL,
                          "roll",
                          &printJsonRoll);

   sobLog("Printing frame video field");

   sobPrintSubobjectByOid(sob,
                          context,
                          frame,
                          SOB_FRAME_VIDEO_ID,
                          SOB_VIDEO,
                          "video",
                          &printJsonVideo);

   sobLog("Printing frame conversation field");

   sobPrintSubobjectByOid(sob,
                          context,
                          frame,
                          SOB_FRAME_CONVERSATION_ID,
                          SOB_CONVERSATION,
                          "conversation",
                          &printJsonConversation);
}

void printJsonRollWithFrames(sobContext sob, mrjsonContext context, bson *roll)
{
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

   sobLog("Printing roll standard fields");

   sobPrintAttributes(context,
                      roll,
                      rollAttributes,
                      sizeof(rollAttributes) / sizeof(sobField));


   sobLog("Printing roll subdomain_active field");
   sobPrintFieldIfBoolField(context,
                            roll,
                            SOB_ROLL_SUBDOMAIN,
                            SOB_ROLL_SUBDOMAIN_ACTIVE);

   sobLog("Checking if roll has creator");
   bson *rollCreator;
   int status = sobGetBsonByOidField(sob,
                                     SOB_USER,
                                     roll,
                                     SOB_ROLL_CREATOR_ID,
                                     &rollCreator);
   if (status) {
      sobLog("Roll has creator, trying to retrieve creator's user type");
      // figure out what type of user this is
      int user_type;
      int foundUserType = sobBsonIntFieldFromObject(sob,
                                                    SOB_USER,
                                                    SOB_USER_USER_TYPE,
                                                    rollCreator,
                                                    &user_type);

      if (foundUserType) {
         sobLog("Creator's user type retrieved");
      } else {
         sobLog("Creator's user type could not be retrieved");
      }
      int creatorAttributesOverride = FALSE;
      if (foundUserType && user_type == 1) {
         // if it's a faux user, override the creator_nickname and creator_name with
         // the corresponding data from the origin network

         bson firstAuth;
         status = sobBsonObjectArrayFieldFirst(SOB_USER,
                                               SOB_USER_AUTHENTICATIONS,
                                               rollCreator,
                                               &firstAuth);
         if (status) {
            sobPrintAttributeWithKeyOverride(context,
                                             &firstAuth,
                                             SOB_AUTHENTICATION_NICKNAME,
                                             "creator_nickname");
            sobPrintAttributeWithKeyOverride(context,
                                             &firstAuth,
                                             SOB_AUTHENTICATION_NAME,
                                             "creator_name");
            creatorAttributesOverride = TRUE;
         }

      }

      if (!creatorAttributesOverride) {
         // if it's not a faux user or we couldn't find an authentication
         // with which to override the nickname and name, just use the roll creator's
         // nickname and name

         sobPrintAttributeWithKeyOverride(context,
                                          rollCreator,
                                          SOB_USER_NICKNAME,
                                          "creator_nickname");

         sobPrintAttributeWithKeyOverride(context,
                                          rollCreator,
                                          SOB_USER_NAME,
                                          "creator_name");
      }

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
   } else {
      sobLog("Roll has no creator");
   }

   sobPrintAttributeWithKeyOverride(context,
                                    roll,
                                    SOB_ROLL_CREATOR_THUMBNAIL_URL,
                                    "thumbnail_url");

   // all frames that we loaded are this roll's frames.
   cvector frames = cvectorAlloc(sizeof(bson *));
   sobGetBsonVector(sob, SOB_FRAME, frames);

   sobLog("Printing roll frames array");

   mrjsonStartArray(context, "frames");
   for (unsigned int i = 0; i < cvectorCount(frames); i++) {
      mrjsonStartNamelessObject(context);
      printJsonFrame(sob, context, *(bson **)cvectorGetElement(frames, i));
      mrjsonEndObject(context);
   }
   mrjsonEndArray(context);
}

void printJsonOutput(sobContext sob)
{
   bson *roll;
   char rollIdString[25];

   bson_oid_to_string(&options.roll, rollIdString);
   sobLog("Printing JSON for roll: %s", rollIdString);

   // TODO: check return status
   sobGetBsonByOid(sob, SOB_ROLL, options.roll, &roll);

   // allocate context; match Ruby API "status" and "result" response syntax
   sobEnvironment environment = sobGetEnvironment(sob);
   mrjsonContext context = mrjsonAllocContext(environment != SOB_PRODUCTION && environment != SOB_STAGING);
   mrjsonStartResponse(context);
   mrjsonIntAttribute(context, "status", 200);
   mrjsonStartObject(context, "result");

   // print main roll with all frames
   printJsonRollWithFrames(sob, context, roll);

   mrjsonEndObject(context);

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
   cvector rollCreatorOids = cvectorAlloc(sizeof(bson_oid_t));
   cvector videoOids = cvectorAlloc(sizeof(bson_oid_t));
   cvector conversationOids = cvectorAlloc(sizeof(bson_oid_t));
   cvector frameAncestorOids = cvectorAlloc(sizeof(bson_oid_t));
   cvector originatorOids = cvectorAlloc(sizeof(bson_oid_t));

   // means we're looking up the public_roll of a user
   if (strcmp(options.rollString, "") == 0 &&
       strcmp(options.userString, "") != 0)
   {
      sobLog("Looking up public roll by creator id: %s", options.userString);
      cvectorAddElement(userOids, &options.user);
      sobLoadAllById(sob, SOB_USER, userOids);
      sobGetOidVectorFromObjectField(sob, SOB_USER, SOB_USER_PUBLIC_ROLL_ID, rollOids);

      assert(cvectorCount(rollOids) == 1);

      // TODO: this is a hack, we should probably be storing this to a better name...
      options.roll = *(bson_oid_t *)cvectorGetElement(rollOids, 0);
   } else {
      sobLog("Looking up roll by roll id: %s", options.rollString);
      assert(strcmp(options.rollString, "") != 0);

      // add this particular roll ID to our vector of rolls to fetch
      cvectorAddElement(rollOids, &options.roll);
   }

   // load all frames with roll oid
   sobLoadAllByOidField(sob,
                        SOB_FRAME,
                        SOB_FRAME_ROLL_ID,
                        options.roll,
                        options.limit,
                        options.skip,
                        options.sinceIdString);

   // and frames have references to everything else, so we load it all up...
   sobGetOidVectorFromObjectField(sob, SOB_FRAME, SOB_FRAME_ROLL_ID, rollOids);
   sobGetOidVectorFromObjectField(sob, SOB_FRAME, SOB_FRAME_CREATOR_ID, userOids);
   sobGetOidVectorFromObjectField(sob, SOB_FRAME, SOB_FRAME_VIDEO_ID, videoOids);
   sobGetOidVectorFromObjectField(sob, SOB_FRAME, SOB_FRAME_CONVERSATION_ID, conversationOids);
   sobGetLastOidVectorFromOidArrayField(sob,
                                        SOB_FRAME,
                                        SOB_FRAME_FRAME_ANCESTORS,
                                        frameAncestorOids);
   sobLoadAllById(sob, SOB_ROLL, rollOids);
   sobLoadAllById(sob, SOB_USER, userOids);
   sobLoadAllById(sob, SOB_VIDEO, videoOids);
   sobLoadAllById(sob, SOB_CONVERSATION, conversationOids);
   sobLoadAllById(sob, SOB_ANCESTOR_FRAME, frameAncestorOids);

   // load the creators of all the rolls (probably just this one roll)
   sobGetOidVectorFromObjectField(sob, SOB_ROLL, SOB_ROLL_CREATOR_ID, rollCreatorOids);
   sobLoadAllById(sob, SOB_USER, rollCreatorOids);

   // get the creators of the final ancestor frames for each frame, whom we will call the originators,
   // then load them
   sobGetOidVectorFromObjectField(sob, SOB_ANCESTOR_FRAME, SOB_ANCESTOR_FRAME_CREATOR_ID, originatorOids);
   sobLoadAllById(sob, SOB_USER, originatorOids);


   sobLog("Checking roll permissions");
   // need to fail if non-public roll has a different user as its creator
   if (!options.permissionGranted &&
       !sobBsonBoolField(sob, SOB_ROLL, SOB_ROLL_PUBLIC, options.roll) &&
       !sobBsonOidFieldEqual(sob, SOB_ROLL, SOB_ROLL_CREATOR_ID, options.roll, options.user))
   {
      sobLog("User DOES NOT have permissions to view roll");
      return FALSE;
   }
   sobLog("User has permissions to view roll");

   return TRUE;
}

int main(int argc, char **argv)
{
   sobLog("------------------------C SAYS: HANDLE /roll/frames START------------------------");

   gettimeofday(&beginTime, NULL);

   int status = 0;

   setDefaultOptions();
   parseUserOptions(argc, argv);

   sobEnvironment env = sobEnvironmentFromString(options.environment);
   sobContext sob = sobAllocContext(env);

   sobLog("BEGIN Load data BEGIN");

   if (!loadData(sob)) {
      status = 2;
      goto cleanup;
   }

   sobLog("END Load data END");

   sobLog("BEGIN Print JSON output BEGIN");

   printJsonOutput(sob);

   sobLog("END Print JSON output END");

   sobLog("------------------------C SAYS: HANDLE /roll/frames END--------------------------");

cleanup:
   sobFreeContext(sob);

   return status;
}
