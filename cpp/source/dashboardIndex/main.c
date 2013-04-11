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
   printf("   -e --environment    Specify environment: production, test, or development\n");
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
      SOB_VIDEO_TAGS,
      SOB_VIDEO_CATEGORIES,
      SOB_VIDEO_FIRST_UNPLAYABLE_AT,
      SOB_VIDEO_LAST_UNPLAYABLE_AT
   };

   sobPrintAttributes(context,
                      video,
                      videoAttributes,
                      sizeof(videoAttributes) / sizeof(sobField));
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

void printJsonUser(sobContext sob, mrjsonContext context, bson *user)
{
   static sobField userAttributes[] = {
      SOB_USER_ID,
      SOB_USER_NAME,
      SOB_USER_NICKNAME,
      SOB_USER_USER_IMAGE_ORIGINAL,
      SOB_USER_USER_IMAGE,
      SOB_USER_FAUX,
      SOB_USER_PUBLIC_ROLL_ID,
      SOB_USER_GT_ENABLED,
   };

   sobPrintStringToBoolAttributeWithKeyOverride(context,
                                                user,
                                                SOB_USER_AVATAR_FILE_NAME,
                                                "has_shelby_avatar");

   sobPrintAttributes(context,
                      user,
                      userAttributes,
                      sizeof(userAttributes) / sizeof(sobField));

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
      SOB_USER_FAUX
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
      SOB_FRAME_LIKE_COUNT
   };
   bson_oid_t originatorFrameOid;
   bson *originatorFrame;
   bson *originator;

   sobPrintAttributes(context,
                      frame,
                      frameAttributes,
                      sizeof(frameAttributes) / sizeof(sobField));

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

      status = sobGetBsonByOidField(sob,
                                        SOB_USER,
                                        originatorFrame,
                                        SOB_ANCESTOR_FRAME_CREATOR_ID,
                                        &originator);

      sobPrintAttributeWithKeyOverride(context,
                                       originator,
                                       SOB_USER_ID,
                                       "originator_id");

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

   sobPrintOidConciseTimeAgoAttribute(context,
                                      frame,
                                      SOB_FRAME_ID,
                                      "created_at");

   sobPrintSubobjectByOid(sob,
                          context,
                          frame,
                          SOB_FRAME_CREATOR_ID,
                          SOB_USER,
                          "creator",
                          &printJsonUser);

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

void printJsonDashboardEntry(sobContext sob, mrjsonContext context, bson *dbEntry)
{
   static sobField dashboardEntryAttributes[] = {
      SOB_DASHBOARD_ENTRY_ID,
      SOB_DASHBOARD_ENTRY_ACTION,
      SOB_DASHBOARD_ENTRY_ACTOR_ID,
      SOB_DASHBOARD_ENTRY_READ,
   };

   sobPrintAttributes(context,
                      dbEntry,
                      dashboardEntryAttributes,
                      sizeof(dashboardEntryAttributes) / sizeof(sobField));

   sobPrintSubobjectByOid(sob,
                          context,
                          dbEntry,
                          SOB_DASHBOARD_ENTRY_FRAME_ID,
                          SOB_FRAME,
                          "frame",
                          &printJsonFrame);
}

void printJsonOutput(sobContext sob)
{
   // get dashboard entries
   cvector dashboardEntries = cvectorAlloc(sizeof(bson *));

   sobGetBsonVector(sob, SOB_DASHBOARD_ENTRY, dashboardEntries);

   // allocate context; match Ruby API "status" and "result" response syntax
   mrjsonContext context = mrjsonAllocContext(sobGetEnvironment(sob) != SOB_PRODUCTION);
   mrjsonStartResponse(context);
   mrjsonIntAttribute(context, "status", 200);
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
   cvector rollOids = cvectorAlloc(sizeof(bson_oid_t));
   cvector userOids = cvectorAlloc(sizeof(bson_oid_t));
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

   // get the creators of the final ancestor frames for each frame, whom we will call the originators,
   // then load them
   sobGetOidVectorFromObjectField(sob, SOB_ANCESTOR_FRAME, SOB_ANCESTOR_FRAME_CREATOR_ID, originatorOids);
   sobLoadAllById(sob, SOB_USER, originatorOids);

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
