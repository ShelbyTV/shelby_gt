#include <iostream>
#include <string>
#include <map>
#include <vector>

#include <stdlib.h>
#include <stdio.h>
#include <sys/time.h>
#include <sys/resource.h>
#include <sys/types.h>
#include <unistd.h>
#include <getopt.h>
#include <assert.h>

#include "lib/mongo-c-driver/src/mongo.h"
#include "lib/mrjson/mrjson.h"
#include "lib/mrbson/mrbson.h"
#include "lib/shelby/shelby.h"

using namespace std;

static struct options {
	string user;
	int limit;
	int skip;
} options;

struct timeval beginTime;

void printHelpText()
{
   cout << "dashboardIndex usage:" << endl;
   cout << "   -h --help        Print this help message" << endl;
   cout << "   -u --user        Lowercase nickname of user" << endl;
   cout << "   -l --limit       Limit to this number of dashboard entries" << endl;
   cout << "   -s --skip        Skip this number of dashboard entries" << endl;
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
         {0, 0, 0, 0}
      };
      
      int option_index = 0;
      c = getopt_long(argc, argv, "hu:l:s:", long_options, &option_index);
   
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

         case 'h': 
         case '?':
         default:
            printHelpText();
            exit(1);
      }
   }
}

void setDefaultOptions()
{
   options.limit = 20;
   options.skip = 0;
}

unsigned int timeSinceMS(struct timeval begin)
{
   struct timeval currentTime;
   gettimeofday(&currentTime, NULL);

   struct timeval difference;
   timersub(&currentTime, &begin, &difference);

   return difference.tv_sec * 1000 + (difference.tv_usec / 1000); 
}

void printJsonMessage(mrjsonContext context, bson *message)
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
      SOB_MESSAGE_PUBLIC
   };

   sobPrintAttributes(context,
                      message,
                      messageAttributes,
                      sizeof(messageAttributes) / sizeof(sobField));

   mrbsonOidConciseTimeAgoAttribute(context, message, "_id", "created_at");
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

   bson messages;
   bson_iterator iterator;
   bson_find(&iterator, conversation, "messages");
   bson_iterator_subobject(&iterator, &messages);

   bson_iterator_from_buffer(&iterator, messages.data);

   mrjsonStartArray(context, "messages");

   while (bson_iterator_next(&iterator)) {
      bson message;
      bson_iterator_subobject(&iterator, &message);

      mrjsonStartObject(context);
      printJsonMessage(context, &message);
      mrjsonEndObject(context);
   }

   mrjsonEndArray(context); 
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
      SOB_ROLL_TITLE,
      SOB_ROLL_ROLL_TYPE,
   };

   sobPrintAttributes(context,
                      roll,
                      rollAttributes,
                      sizeof(rollAttributes) / sizeof(sobField));

   mrbsonStringAttribute(context, roll, "c", "thumbnail_url");
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

   mrbsonOidConciseTimeAgoAttribute(context, frame, "_id", "created_at");

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
   // get dashboard entries; we'll iterate ourselves for the ordering hack (see below)
   vector<bson *> dashboardEntries;
   sobGetBsonVector(sob, SOB_DASHBOARD_ENTRY, dashboardEntries);

   // allocate context; match Ruby API "status" and "result" response syntax
   mrjsonContext context = mrjsonAllocContext(true);
   mrjsonStartResponse(context); 
   mrjsonIntAttribute(context, "status", 200);
   mrjsonStartArray(context, "result");

   // hack to match ordering of Ruby API - reverse iterate over map order returned
   for (vector<bson *>::const_reverse_iterator iter = dashboardEntries.rbegin();
        iter != dashboardEntries.rend();
        ++iter) {

      mrjsonStartObject(context);
      printJsonDashboardEntry(sob, context, *iter);
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
bool loadData(sobContext sob)
{
   bson_oid_t userOid;
   vector<bson_oid_t> frameOids, rollOids, userOids, videoOids, conversationOids;

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
                        -1);

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
   sobLoadAllById(sob, SOB_ROLL, rollOids);
   sobLoadAllById(sob, SOB_USER, userOids);
   sobLoadAllById(sob, SOB_VIDEO, videoOids);
   sobLoadAllById(sob, SOB_CONVERSATION, conversationOids);

   return true;
}

int main(int argc, char **argv)
{
   gettimeofday(&beginTime, NULL);

   int status = 0;

   setDefaultOptions();
   parseUserOptions(argc, argv);

   sobContext sob = sobAllocContext(SOB_DEVELOPMENT);
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
