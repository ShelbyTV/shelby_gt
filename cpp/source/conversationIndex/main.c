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
   char* videoString;
   bson_oid_t video;
   int limit;
   char *environment;
} options;

bson_oid_t videoOid;

struct timeval beginTime;

void printHelpText()
{
   printf("conversationIndex usage:\n"); 
   printf("   -h --help           Print this help message\n");
   printf("   -v --video          String representation of video mongo ID\n");
   printf("   -l --limit          Limit number of returned conversations\n");
   printf("   -e --environment    Specify environment: production, test, or development\n");
}

void parseUserOptions(int argc, char **argv)
{
   int c;
     
   while (1) {
      static struct option long_options[] =
      {
         {"help",        no_argument,       0, 'h'},
         {"video",       required_argument, 0, 'v'},
         {"limit",       no_argument,       0, 'l'},
         {"environment", required_argument, 0, 'e'},
         {0, 0, 0, 0}
      };
      
      int option_index = 0;
      c = getopt_long(argc, argv, "hv:l:e:", long_options, &option_index);
   
      /* Detect the end of the options. */
      if (c == -1) {
         break;
      }
   
      switch (c)
      {
         case 'v':
            options.videoString = optarg;
            bson_oid_from_string(&options.video, optarg); 
            break;

         case 'l':
            options.limit = atoi(optarg);
            break;

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
   
   if (strcmp(options.videoString, "") == 0) {
      printf("Specifying -v or --video is required.\n");
      printHelpText();
      exit(1);
   }
}

void setDefaultOptions()
{
   options.videoString = "";
   options.limit = 50;
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

void printJsonConversation(sobContext sob,
                           mrjsonContext context,
                           bson *conversation)
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

void printJsonOutput(sobContext sob)
{
   // get conversations
   cvector conversations = cvectorAlloc(sizeof(bson *));
   sobGetBsonVector(sob, SOB_CONVERSATION, conversations);

   // allocate context; match Ruby API "status" and "result" response syntax
   mrjsonContext context = mrjsonAllocContext(sobGetEnvironment(sob) != SOB_PRODUCTION);
   mrjsonStartResponse(context); 
   mrjsonIntAttribute(context, "status", 200);
   mrjsonStartArray(context, "result");

   for (int i = 0; i < cvectorCount(conversations); i++) {
      mrjsonStartNamelessObject(context);
      printJsonConversation(sob,
                            context,
                            *(bson **)cvectorGetElement(conversations, i));
      mrjsonEndObject(context);
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
   sobLoadAllByOidField(sob,
                        SOB_CONVERSATION, 
                        SOB_CONVERSATION_VIDEO_ID,
                        options.video,
                        options.limit,
                        0,
                        "");

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
   if (!sob || !sobConnect(sob)) {
      status = 1;
      goto cleanup;
   } 

   if (!loadData(sob)) {
      status = 2;
      goto cleanup;
   }

   printJsonOutput(sob);

cleanup:
   sobFreeContext(sob);

   return status;
}
