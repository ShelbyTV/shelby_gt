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
} options;

struct timeval beginTime;

void printHelpText()
{
   printf("frameIndex usage:\n"); 
   printf("   -h --help           Print this help message\n");
   printf("   -u --user           String representation of user OID\n");
   printf("   -r --roll           String representation of roll OID\n");
   printf("   -l --limit          Limit to this number of frames\n");
   printf("   -s --skip           Skip this number of frames\n");
   printf("   -i --sinceid        Frames since this one (inclusive)\n");
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
         {"roll",        required_argument, 0, 'r'},
         {"limit",       required_argument, 0, 'l'},
         {"skip",        required_argument, 0, 's'},
         {"sinceid",     required_argument, 0, 'i'},
         {"environment", required_argument, 0, 'e'},
         {0, 0, 0, 0}
      };
      
      int option_index = 0;
      c = getopt_long(argc, argv, "hr:l:s:e:u:i:", long_options, &option_index);
   
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
      SOB_VIDEO_CATEGORIES
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
      SOB_ROLL_HEADER_IMAGE_FILE_NAME,
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

   sobPrintFieldIfBoolField(context,
                            roll,
                            SOB_ROLL_SUBDOMAIN,
                            SOB_ROLL_SUBDOMAIN_ACTIVE);

}

void printJsonUser(sobContext sob, mrjsonContext context, bson *user)
{
   static sobField userAttributes[] = {
      SOB_USER_ID,
      SOB_USER_NAME,
      SOB_USER_NICKNAME,
      SOB_USER_USER_IMAGE_ORIGINAL,
      SOB_USER_USER_IMAGE,
      SOB_USER_PUBLIC_ROLL_ID,
   };
   
   sobPrintStringToBoolAttributeWithKeyOverride(context,
                                                user,
                                                SOB_USER_AVATAR_FILE_NAME,
                                                "has_shelby_avatar");

   sobPrintAttributes(context,
                      user,
                      userAttributes,
                      sizeof(userAttributes) / sizeof(sobField));
}

/*
 * There are some attributes in the Ruby API that this C API is not printing 
 * (because they seem outdated / unused):
 *
 *  - upvoters
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
   };

   sobPrintAttributes(context,
                      frame,
                      frameAttributes,
                      sizeof(frameAttributes) / sizeof(sobField));

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

      sobPrintStringToBoolAttributeWithKeyOverride(context,
                                                   rollCreator,
                                                   SOB_USER_AVATAR_FILE_NAME,
                                                   "creator_has_shelby_avatar");

      sobPrintAttributeWithKeyOverride(context,
                                       rollCreator,
                                       SOB_USER_AVATAR_UPDATED_AT,
                                       "creator_avatar_updated_at");
   }

   sobPrintAttributeWithKeyOverride(context,
                                    roll,
                                    SOB_ROLL_CREATOR_THUMBNAIL_URL,
                                    "thumbnail_url");

   // all frames that we loaded are this roll's frames.
   cvector frames = cvectorAlloc(sizeof(bson *));
   sobGetBsonVector(sob, SOB_FRAME, frames);
   
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

   // TODO: check return status
   sobGetBsonByOid(sob, SOB_ROLL, options.roll, &roll);

   // allocate context; match Ruby API "status" and "result" response syntax
   mrjsonContext context = mrjsonAllocContext(sobGetEnvironment(sob) != SOB_PRODUCTION);
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
   cvector videoOids = cvectorAlloc(sizeof(bson_oid_t));
   cvector conversationOids = cvectorAlloc(sizeof(bson_oid_t));

   // means we're looking up the public_roll of a user
   if (strcmp(options.rollString, "") == 0 &&
       strcmp(options.userString, "") != 0)
   {
      cvectorAddElement(userOids, &options.user);
      sobLoadAllById(sob, SOB_USER, userOids);
      sobGetOidVectorFromObjectField(sob, SOB_USER, SOB_USER_PUBLIC_ROLL_ID, rollOids);

      assert(cvectorCount(rollOids) == 1);

      // TODO: this is a hack, we should probably be storing this to a better name...
      options.roll = *(bson_oid_t *)cvectorGetElement(rollOids, 0);
   } else {
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
   sobLoadAllById(sob, SOB_ROLL, rollOids);
   sobLoadAllById(sob, SOB_USER, userOids);
   sobLoadAllById(sob, SOB_VIDEO, videoOids);
   sobLoadAllById(sob, SOB_CONVERSATION, conversationOids);

   // need to fail if non-public roll has a different user as its creator
   if (!sobBsonBoolField(sob, SOB_ROLL, SOB_ROLL_PUBLIC, options.roll) &&
       !sobBsonOidFieldEqual(sob, SOB_ROLL, SOB_ROLL_CREATOR_ID, options.roll, options.user))
   {
      return FALSE;
   }

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
