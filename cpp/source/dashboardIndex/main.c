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

#define ACTION_ENTERTAINMENT_GRAPH_REC 32

static struct options {
   char *user;
   int limit;
   int skip;
   char *environment;

   char *sinceIdString;
} options;

struct timeval beginTime;

void printHelpText()
{
   printf("dashboardIndex usage:\n");
   printf("   -h --help           Print this help message\n");
   printf("   -u --user           Lowercase nickname of user\n");
   printf("   -l --limit          Limit to this number of dashboard entries\n");
   printf("   -s --skip           Skip this number of dashboard entries\n");
   printf("   -i --sinceid        Dashboard entries since this one (inclusive)\n");
   printf("   -e --environment    Specify environment: production, staging, test, or development\n");
}

void parseUserOptions(int argc, char **argv)
{
   int c;

   while (1) {
      static struct option long_options[] =
      {
         {"help",        no_argument,       0, 'h'},
         {"user",        required_argument, 0, 'u'},
         {"limit",       required_argument, 0, 'l'},
         {"skip",        required_argument, 0, 's'},
         {"sinceid",     required_argument, 0, 'i'},
         {"environment", required_argument, 0, 'e'},
         {0, 0, 0, 0}
      };

      int option_index = 0;
      c = getopt_long(argc, argv, "hu:l:s:e:i:", long_options, &option_index);

      /* Detect the end of the options. */
      if (c == -1) {
         break;
      }

      switch (c)
      {
         case 'u':
            options.user = optarg;
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

   if (strcmp(options.user, "") == 0) {
      printf("Specifying -u or --user is required.\n");
      printHelpText();
      exit(1);
   }
}

void setDefaultOptions()
{
   options.user = "";
   options.limit = 20;
   options.skip = 0;
   options.environment = "";
   options.sinceIdString = "";
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

   sobPrintAttributes(context,
                      video,
                      videoAttributes,
                      sizeof(videoAttributes) / sizeof(sobField));

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
      SOB_ROLL_TITLE,
      SOB_ROLL_ROLL_TYPE,
   };

   sobPrintAttributes(context,
                      roll,
                      rollAttributes,
                      sizeof(rollAttributes) / sizeof(sobField));

   sobPrintAttributeWithKeyOverride(context,
                                    roll,
                                    SOB_ROLL_CREATOR_THUMBNAIL_URL,
                                    "thumbnail_url");
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

void printJsonCreator(sobContext sob, mrjsonContext context, bson *creator)
{
   static sobField creatorAttributes[] = {
      SOB_CREATOR_ID,
      SOB_CREATOR_NAME,
      SOB_CREATOR_NICKNAME,
      SOB_CREATOR_USER_IMAGE_ORIGINAL,
      SOB_CREATOR_USER_IMAGE,
      SOB_CREATOR_USER_TYPE,
      SOB_CREATOR_PUBLIC_ROLL_ID,
      SOB_CREATOR_GT_ENABLED,
   };

   sobPrintStringToBoolAttributeWithKeyOverride(context,
                                                creator,
                                                SOB_CREATOR_AVATAR_FILE_NAME,
                                                "has_shelby_avatar");

   sobPrintAttributes(context,
                      creator,
                      creatorAttributes,
                      sizeof(creatorAttributes) / sizeof(sobField));

   sobPrintSubobjectArray(sob,
                          context,
                          creator,
                          SOB_CREATOR_AUTHENTICATIONS,
                          &printJsonAuthentication);
}

void printJsonOriginator(sobContext sob, mrjsonContext context, bson *originator)
{
   static sobField originatorAttributes[] = {
      SOB_ORIGINATOR_ID,
      SOB_ORIGINATOR_NAME,
      SOB_ORIGINATOR_NICKNAME,
      SOB_ORIGINATOR_USER_TYPE
   };

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
                                        SOB_ORIGINATOR,
                                        originatorFrame,
                                        SOB_ANCESTOR_FRAME_CREATOR_ID,
                                        &originator);

      if (status) {
         sobLog("Printing frame originator_id field");
         sobPrintAttributeWithKeyOverride(context,
                                          originator,
                                          SOB_ORIGINATOR_ID,
                                          "originator_id");

         sobLog("Printing frame originator field");
         sobPrintSubobjectByOid(sob,
                                context,
                                originatorFrame,
                                SOB_ANCESTOR_FRAME_CREATOR_ID,
                                SOB_ORIGINATOR,
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

   sobPrintOidConciseTimeAgoAttribute(context,
                                      frame,
                                      SOB_FRAME_ID,
                                      "created_at");

   sobPrintSubobjectByOid(sob,
                          context,
                          frame,
                          SOB_FRAME_CREATOR_ID,
                          SOB_CREATOR,
                          "creator",
                          &printJsonCreator);

   sobPrintSubobjectByOid(sob,
                          context,
                          frame,
                          SOB_FRAME_ROLL_ID,
                          SOB_ROLL,
                          "roll",
                          &printJsonRoll);

   sobPrintSubobjectByOid(sob,
                          context,
                          frame,
                          SOB_FRAME_VIDEO_ID,
                          SOB_VIDEO,
                          "video",
                          &printJsonVideo);

   sobPrintSubobjectByOid(sob,
                          context,
                          frame,
                          SOB_FRAME_CONVERSATION_ID,
                          SOB_CONVERSATION,
                          "conversation",
                          &printJsonConversation);
}

void printJsonSourceFrameCreator(sobContext sob, mrjsonContext context, bson *sourceFrameCreator)
{
   static sobField sourceFrameCreatorAttributes[] = {
      SOB_CREATOR_ID,
      SOB_CREATOR_NICKNAME
   };

   sobPrintAttributes(context,
                      sourceFrameCreator,
                      sourceFrameCreatorAttributes,
                      sizeof(sourceFrameCreatorAttributes) / sizeof(sobField));
}

void printJsonSourceFrame(sobContext sob, mrjsonContext context, bson *sourceFrame)
{
   static sobField sourceFrameAttributes[] = {
      SOB_FRAME_ID,
      SOB_FRAME_CREATOR_ID
   };

   sobPrintAttributes(context,
                      sourceFrame,
                      sourceFrameAttributes,
                      sizeof(sourceFrameAttributes) / sizeof(sobField));

   sobPrintSubobjectByOid(sob,
                          context,
                          sourceFrame,
                          SOB_FRAME_CREATOR_ID,
                          SOB_CREATOR,
                          "creator",
                          &printJsonSourceFrameCreator);
}

void printJsonSourceVideo(sobContext sob, mrjsonContext context, bson *sourceVideo)
{
   static sobField sourceVideoAttributes[] = {
      SOB_VIDEO_ID,
      SOB_VIDEO_TITLE
   };

   sobPrintAttributes(context,
                      sourceVideo,
                      sourceVideoAttributes,
                      sizeof(sourceVideoAttributes) / sizeof(sobField));
}

void printJsonActor(sobContext sob, mrjsonContext context, bson *actor)
{
   static sobField actorAttributes[] = {
      SOB_ACTOR_ID,
      SOB_ACTOR_NAME,
      SOB_ACTOR_NICKNAME,
      SOB_ACTOR_USER_IMAGE_ORIGINAL,
      SOB_ACTOR_USER_IMAGE,
      SOB_ACTOR_USER_TYPE,
      SOB_ACTOR_PUBLIC_ROLL_ID,
   };

   sobPrintStringToBoolAttributeWithKeyOverride(context,
                                                actor,
                                                SOB_ACTOR_AVATAR_FILE_NAME,
                                                "has_shelby_avatar");

   sobPrintAttributes(context,
                      actor,
                      actorAttributes,
                      sizeof(actorAttributes) / sizeof(sobField));
}

void printJsonDashboardEntry(sobContext sob, mrjsonContext context, bson *dbEntry)
{
   static sobField dashboardEntryAttributes[] = {
      SOB_DASHBOARD_ENTRY_ID,
      SOB_DASHBOARD_ENTRY_USER_ID,
      SOB_DASHBOARD_ENTRY_ACTION,
      SOB_DASHBOARD_ENTRY_ACTOR_ID,
      SOB_DASHBOARD_ENTRY_READ
   };

   bson_oid_t dbEntryOid;

   sobBsonOidField(SOB_DASHBOARD_ENTRY,
                   SOB_DASHBOARD_ENTRY_ID,
                   dbEntry,
                   &dbEntryOid);

   char dbEntryIdString[25];

   bson_oid_to_string(&dbEntryOid, dbEntryIdString);
   sobLog("Printing JSON for dbEntry: %s", dbEntryIdString);

   sobLog("Printing dashboard entry standard fields");

   sobPrintAttributes(context,
                      dbEntry,
                      dashboardEntryAttributes,
                      sizeof(dashboardEntryAttributes) / sizeof(sobField));

   sobLog("Printing dashboard entry frame field");

   sobPrintSubobjectByOid(sob,
                          context,
                          dbEntry,
                          SOB_DASHBOARD_ENTRY_FRAME_ID,
                          SOB_FRAME,
                          "frame",
                          &printJsonFrame);

   sobLog("Printing dashboard entry actor field");

   sobPrintSubobjectByOid(sob,
                          context,
                          dbEntry,
                          SOB_DASHBOARD_ENTRY_ACTOR_ID,
                          SOB_ACTOR,
                          "actor",
                          &printJsonActor);

   // include the friend arrays, only if the entry is an entertainment graph recommendation
   sobLog("Checking if dashboard entry is an entertainment graph recommendation");
   int action;
   int status = sobBsonIntFieldFromObject(sob,
                                          SOB_DASHBOARD_ENTRY,
                                          SOB_DASHBOARD_ENTRY_ACTION,
                                          dbEntry,
                                          &action);

   if (status && action == ACTION_ENTERTAINMENT_GRAPH_REC) {

      sobLog("Printing dashboard entry friend_sharers field");

      sobPrintAttributeWithKeyOverride(context,
                                       dbEntry,
                                       SOB_DASHBOARD_ENTRY_FRIEND_SHARERS_ARRAY,
                                       "friend_sharers");

      sobLog("Printing dashboard entry friend_viewers field");

      sobPrintAttributeWithKeyOverride(context,
                                       dbEntry,
                                       SOB_DASHBOARD_ENTRY_FRIEND_VIEWERS_ARRAY,
                                       "friend_viewers");

      sobLog("Printing dashboard entry friend_likers field");

      sobPrintAttributeWithKeyOverride(context,
                                       dbEntry,
                                       SOB_DASHBOARD_ENTRY_FRIEND_LIKERS_ARRAY,
                                       "friend_likers");

      sobLog("Printing dashboard entry friend_rollers field");

      sobPrintAttributeWithKeyOverride(context,
                                       dbEntry,
                                       SOB_DASHBOARD_ENTRY_FRIEND_ROLLERS_ARRAY,
                                       "friend_rollers");

      sobLog("Printing dashboard entry friend_complete_viewers field");

      sobPrintAttributeWithKeyOverride(context,
                                       dbEntry,
                                       SOB_DASHBOARD_ENTRY_FRIEND_COMPLETE_VIEWERS_ARRAY,
                                       "friend_complete_viewers");
   }

   // include the src_frame attribute, only if the entry has a source frame
   sobLog("Checking if dashboard entry has src_frame");
   bson_oid_t sourceFrameOid;
   int hasSourceFrame = sobBsonOidField(SOB_DASHBOARD_ENTRY,
                                        SOB_DASHBOARD_ENTRY_SRC_FRAME_ID,
                                        dbEntry,
                                        &sourceFrameOid);
   if (hasSourceFrame) {
      sobLog("Printing dashboard entry src_frame field");
      sobPrintSubobjectByOid(sob,
                             context,
                             dbEntry,
                             SOB_DASHBOARD_ENTRY_SRC_FRAME_ID,
                             SOB_FRAME,
                             "src_frame",
                             &printJsonSourceFrame);
   }

   // include the src_video attribute, only if the entry has a source video
   sobLog("Checking if dashboard entry has src_video");
   bson_oid_t sourceVideoOid;
   int hasSourceVideo = sobBsonOidField(SOB_DASHBOARD_ENTRY,
                                        SOB_DASHBOARD_ENTRY_SRC_VIDEO_ID,
                                        dbEntry,
                                        &sourceVideoOid);
   if (hasSourceVideo) {
      sobLog("Printing dashboard entry src_video field");
      sobPrintSubobjectByOid(sob,
                             context,
                             dbEntry,
                             SOB_DASHBOARD_ENTRY_SRC_VIDEO_ID,
                             SOB_VIDEO,
                             "src_video",
                             &printJsonSourceVideo);
   }
}

void printJsonOutput(sobContext sob)
{
   // get dashboard entries
   cvector dashboardEntries = cvectorAlloc(sizeof(bson *));

   sobGetBsonVector(sob, SOB_DASHBOARD_ENTRY, dashboardEntries);

   // allocate context; match Ruby API "status" and "result" response syntax
   sobEnvironment environment = sobGetEnvironment(sob);
   mrjsonContext context = mrjsonAllocContext(environment != SOB_PRODUCTION && environment != SOB_STAGING);
   mrjsonStartResponse(context);
   mrjsonIntAttribute(context, "status", 200);

   sobLog("Printing dashboard entries array");

   mrjsonStartArray(context, "result");

   for (unsigned int i = 0; i < cvectorCount(dashboardEntries); i++) {
      mrjsonStartNamelessObject(context);
      printJsonDashboardEntry(sob, context, *(bson **)cvectorGetElement(dashboardEntries, i));
      mrjsonEndObject(context);
   }

   // finish dashboard entries; we also tack on a field to track execution time of the API
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
   bson_oid_t userOid;
   cvector frameOids = cvectorAlloc(sizeof(bson_oid_t));
   cvector srcFrameOids = cvectorAlloc(sizeof(bson_oid_t));
   cvector srcVideoOids = cvectorAlloc(sizeof(bson_oid_t));
   cvector actorOids = cvectorAlloc(sizeof(bson_oid_t));
   cvector rollOids = cvectorAlloc(sizeof(bson_oid_t));
   cvector creatorOids = cvectorAlloc(sizeof(bson_oid_t));
   cvector videoOids = cvectorAlloc(sizeof(bson_oid_t));
   cvector conversationOids = cvectorAlloc(sizeof(bson_oid_t));
   cvector frameAncestorOids = cvectorAlloc(sizeof(bson_oid_t));
   cvector originatorOids = cvectorAlloc(sizeof(bson_oid_t));

   // first we get the user id for the target user (passed in as an option)
   userOid = sobGetUniqueOidByStringField(sob,
                                          SOB_USER,
                                          SOB_USER_DOWNCASE_NICKNAME,
                                          options.user);

   // then we load all the requested dashboard entries for the user
   sobLoadAllByOidField(sob,
                        SOB_DASHBOARD_ENTRY,
                        SOB_DASHBOARD_ENTRY_USER_ID,
                        userOid,
                        options.limit,
                        options.skip,
                        options.sinceIdString);

   // then we get all frames referenced by the dashboard entries
   sobGetOidVectorFromObjectField(sob,
                                  SOB_DASHBOARD_ENTRY,
                                  SOB_DASHBOARD_ENTRY_FRAME_ID,
                                  frameOids);

   sobLoadAllById(sob, SOB_FRAME, frameOids);

   // and all source frames referenced by the dashboard entries
   sobGetOidVectorFromObjectField(sob,
                                  SOB_DASHBOARD_ENTRY,
                                  SOB_DASHBOARD_ENTRY_SRC_FRAME_ID,
                                  srcFrameOids);

   sobLoadAllById(sob, SOB_FRAME, srcFrameOids);

   // and all source videos referenced by the dashboard entries
   sobGetOidVectorFromObjectField(sob,
                                  SOB_DASHBOARD_ENTRY,
                                  SOB_DASHBOARD_ENTRY_SRC_VIDEO_ID,
                                  srcVideoOids);

   sobLoadAllById(sob, SOB_VIDEO, srcVideoOids);

   // and all actors referenced by the dashboard entries
   sobGetOidVectorFromObjectField(sob,
                                  SOB_DASHBOARD_ENTRY,
                                  SOB_DASHBOARD_ENTRY_ACTOR_ID,
                                  actorOids);

   static sobField actorFields[] = {
      SOB_ACTOR_ID,
      SOB_ACTOR_NAME,
      SOB_ACTOR_NICKNAME,
      SOB_ACTOR_USER_IMAGE_ORIGINAL,
      SOB_ACTOR_USER_IMAGE,
      SOB_ACTOR_USER_TYPE,
      SOB_ACTOR_PUBLIC_ROLL_ID,
      SOB_ACTOR_AVATAR_FILE_NAME
   };
   sobLoadAllByIdSpecifyFields(sob,
                            SOB_ACTOR,
                            actorFields,
                            sizeof(actorFields) / sizeof(sobField),
                            actorOids);

   // and frames have references to everything else, so we load it all up...
   sobGetOidVectorFromObjectField(sob, SOB_FRAME, SOB_FRAME_ROLL_ID, rollOids);
   sobGetOidVectorFromObjectField(sob, SOB_FRAME, SOB_FRAME_CREATOR_ID, creatorOids);
   sobGetOidVectorFromObjectField(sob, SOB_FRAME, SOB_FRAME_VIDEO_ID, videoOids);
   sobGetOidVectorFromObjectField(sob, SOB_FRAME, SOB_FRAME_CONVERSATION_ID, conversationOids);
   sobGetLastOidVectorFromOidArrayField(sob,
                                        SOB_FRAME,
                                        SOB_FRAME_FRAME_ANCESTORS,
                                        frameAncestorOids);
   sobLoadAllById(sob, SOB_ROLL, rollOids);

   static sobField creatorFields[] = {
      SOB_CREATOR_ID,
      SOB_CREATOR_NAME,
      SOB_CREATOR_NICKNAME,
      SOB_CREATOR_USER_IMAGE_ORIGINAL,
      SOB_CREATOR_USER_IMAGE,
      SOB_CREATOR_USER_TYPE,
      SOB_CREATOR_PUBLIC_ROLL_ID,
      SOB_CREATOR_GT_ENABLED,
      SOB_CREATOR_AVATAR_FILE_NAME,
      SOB_CREATOR_AUTHENTICATIONS
   };
   sobLoadAllByIdSpecifyFields(sob,
                               SOB_CREATOR,
                               creatorFields,
                               sizeof(creatorFields) / sizeof(sobField),
                               creatorOids);

   sobLoadAllById(sob, SOB_VIDEO, videoOids);
   sobLoadAllById(sob, SOB_CONVERSATION, conversationOids);
   sobLoadAllById(sob, SOB_ANCESTOR_FRAME, frameAncestorOids);

   // get the creators of the final ancestor frames for each frame, whom we will call the originators,
   // then load them
   sobGetOidVectorFromObjectField(sob, SOB_ANCESTOR_FRAME, SOB_ANCESTOR_FRAME_CREATOR_ID, originatorOids);
   static sobField originatorFields[] = {
      SOB_ORIGINATOR_ID,
      SOB_ORIGINATOR_NAME,
      SOB_ORIGINATOR_NICKNAME,
      SOB_ORIGINATOR_USER_TYPE
   };
   sobLoadAllByIdSpecifyFields(sob,
                               SOB_ORIGINATOR,
                               originatorFields,
                               sizeof(originatorFields) / sizeof(sobField),
                               originatorOids);

   return TRUE;
}

int main(int argc, char **argv)
{
   sobLog("------------------------C SAYS: HANDLE /dashboard START------------------------");

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

   sobLog("------------------------C SAYS: HANDLE /dashboard END--------------------------");

cleanup:
   sobFreeContext(sob);

   return status;
}
