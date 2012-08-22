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
	int postable;
	char *environment;
} options;

struct timeval beginTime;

void printHelpText()
{
   printf("userRollFollowings usage:\n"); 
   printf("   -h --help           Print this help message\n");
   printf("   -u --user           User downcase nickname\n");
   printf("   -p --postable       Only return postable rolls\n");
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
         {"postable",    no_argument,       0, 'p'},
         {"environment", required_argument, 0, 'e'},
         {0, 0, 0, 0}
      };
      
      int option_index = 0;
      c = getopt_long(argc, argv, "hu:pe:", long_options, &option_index);
   
      /* Detect the end of the options. */
      if (c == -1) {
         break;
      }
   
      switch (c)
      {
         case 'u':
            options.user = optarg;
            break;

         case 'p':
            options.postable = TRUE;
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
   
   if (strcmp(options.user, "") == 0) {
      printf("Specifying -u or --user is required.\n");
      printHelpText();
      exit(1);
   }
}

void setDefaultOptions()
{
   options.user = "";
   options.postable = FALSE;
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
   }
   
   sobPrintAttributeWithKeyOverride(context,
                                    roll,
                                    SOB_ROLL_CREATOR_THUMBNAIL_URL,
                                    "thumbnail_url");

   // TODO: following_user_count, followed_at
}

void printJsonOutput(sobContext sob)
{
   // allocate context; match Ruby API "status" and "result" response syntax
   mrjsonContext context = mrjsonAllocContext(sobGetEnvironment(sob) != SOB_PRODUCTION);
   mrjsonStartResponse(context); 
   mrjsonIntAttribute(context, "status", 200);
   mrjsonStartArray(context, "result");

   // TODO: print all rolls
   // printJsonRoll(sob, context, roll);

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
//   bson_oid_t userOid;

//   cvector rollOids = cvectorAlloc(sizeof(bson_oid_t));
//   cvector userOids = cvectorAlloc(sizeof(bson_oid_t));

   // first we get the user id for the target user (passed in as an option)
//   userOid = sobGetUniqueOidByStringField(sob,
//                                          SOB_USER,
//                                          SOB_USER_DOWNCASE_NICKNAME,
//                                          options.user);

   // load all frames with roll oid
//   sobLoadAllByOidField(sob,
//                        SOB_FRAME, 
//                        SOB_FRAME_ROLL_ID,
//                        userOid, // TODO: fix
//                        0,
//                        0,
//                        -1);
//
//   sobLoadAllById(sob, SOB_ROLL, rollOids);

   // and frames have references to everything else, so we load it all up...
//   sobGetOidVectorFromObjectField(sob, SOB_FRAME, SOB_FRAME_ROLL_ID, rollOids);
//   sobGetOidVectorFromObjectField(sob, SOB_FRAME, SOB_FRAME_CREATOR_ID, userOids);
//   sobLoadAllById(sob, SOB_ROLL, rollOids);
//   sobLoadAllById(sob, SOB_USER, userOids);

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
