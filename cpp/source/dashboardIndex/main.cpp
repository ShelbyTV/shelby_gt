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
   mrbsonOidAttribute(context, message, "_id", "id");
   mrbsonStringAttribute(context, message, "e", "nickname");
   mrbsonStringAttribute(context, message, "f", "realname");
   mrbsonStringAttribute(context, message, "g", "user_image_url");
   mrbsonStringAttribute(context, message, "h", "text");
   mrbsonStringAttribute(context, message, "a", "origin_network");
   mrbsonStringAttribute(context, message, "b", "origin_id");
   mrbsonStringAttribute(context, message, "c", "origin_user_id");
   mrbsonOidAttribute(context, message, "d", "user_id");
   mrbsonBoolAttribute(context, message, "i", "public");
   mrbsonOidConciseTimeAgoAttribute(context, message, "_id", "created_at");
}

void printJsonConversation(mrjsonContext context, bson *conversation)
{
   mrbsonOidAttribute(context, conversation, "_id", "id");
   mrbsonBoolAttribute(context, conversation, "b", "public");
 
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

void printJsonVideo(mrjsonContext context, bson *video)
{
   mrbsonOidAttribute(context, video, "_id", "id");
   mrbsonStringAttribute(context, video, "a", "provider_name");
   mrbsonStringAttribute(context, video, "b", "provider_id");
   mrbsonStringAttribute(context, video, "c", "title");
   mrbsonStringAttribute(context, video, "e", "description");
   mrbsonStringAttribute(context, video, "f", "duration");
   mrbsonStringAttribute(context, video, "g", "author");
   mrbsonStringAttribute(context, video, "j", "thumbnail_url");

   // TODO: need these
   mrjsonEmptyArrayAttribute(context, "tags");
   mrjsonEmptyArrayAttribute(context, "categories");

   mrbsonStringAttribute(context, video, "o", "source_url");
   mrbsonStringAttribute(context, video, "p", "embed_url");
   mrbsonIntAttribute(context, video, "view_count", "view_count");
   
}

void printJsonRoll(mrjsonContext context, bson *roll)
{
   mrbsonOidAttribute(context, roll, "_id", "id");
   mrbsonBoolAttribute(context, roll, "e", "collaborative");
   mrbsonBoolAttribute(context, roll, "d", "public");
   mrbsonOidAttribute(context, roll, "a", "creator_id");
   mrbsonStringAttribute(context, roll, "f", "origin_network");
   mrbsonBoolAttribute(context, roll, "h", "genius");
   mrbsonIntAttribute(context, roll, "j", "frame_count");
   mrbsonStringAttribute(context, roll, "m", "first_frame_thumbnail_url");
   mrbsonStringAttribute(context, roll, "b", "title");
   mrbsonIntAttribute(context, roll, "n", "roll_type");
   mrbsonStringAttribute(context, roll, "c", "thumbnail_url");
}

void printJsonUser(mrjsonContext context, bson *user)
{
   mrbsonOidAttribute(context, user, "_id", "id");
   mrbsonStringAttribute(context, user, "name", "name");
   mrbsonStringAttribute(context, user, "nickname", "nickname");
   mrbsonStringAttribute(context, user, "user_image_original", "user_image_original");
   mrbsonStringAttribute(context, user, "user_image", "user_image");
   mrbsonIntAttribute(context, user, "ac", "faux");
   mrbsonOidAttribute(context, user, "ab", "public_roll_id");
   mrbsonBoolAttribute(context, user, "ag", "gt_enabled");
}

void printJsonFrame(sobContext sob, mrjsonContext context, bson *frame)
{
   mrbsonOidAttribute(context, frame, "_id", "id");
   mrbsonDoubleAttribute(context, frame, "e", "score");
   
   // TODO: need to figure out correct approach to upvoters
   mrjsonEmptyArrayAttribute(context, "upvoters");

   mrbsonIntAttribute(context, frame, "view_count", "view_count");

   // TODO: need to figure these out
   mrjsonEmptyArrayAttribute(context, "frame_ancestors");
   mrjsonEmptyArrayAttribute(context, "frame_children");

   mrbsonOidAttribute(context, frame, "d", "creator_id");
   mrbsonOidAttribute(context, frame, "c", "conversation_id");
   mrbsonOidAttribute(context, frame, "a", "roll_id");
   mrbsonOidAttribute(context, frame, "b", "video_id");

   // TODO: timestamp
   mrjsonNullAttribute(context, "timestamp");

   mrbsonOidConciseTimeAgoAttribute(context, frame, "_id", "created_at");

   bson_oid_t creatorOid;
   bson *creatorBson;

   if (mrbsonFindOid(frame, "d", &creatorOid) &&
       sobGetBsonByOid(sob, SOB_USER, creatorOid, &creatorBson)) {

      mrjsonStartObject(context, "creator");
      printJsonUser(context, creatorBson);
      mrjsonEndObject(context);

   } else {
      mrjsonNullAttribute(context, "creator");
   }


   // TODO: upvote_users
   mrjsonEmptyArrayAttribute(context, "upvote_users");


   bson_oid_t rollOid;
   bson *rollBson;

   if (mrbsonFindOid(frame, "a", &rollOid) &&
       sobGetBsonByOid(sob, SOB_ROLL, rollOid, &rollBson)) {

      mrjsonStartObject(context, "roll");
      printJsonRoll(context, rollBson);
      mrjsonEndObject(context);

   } else {
      mrjsonNullAttribute(context, "roll");
   }


   bson_oid_t videoOid;
   bson *videoBson;

   if (mrbsonFindOid(frame, "b", &videoOid) &&
       sobGetBsonByOid(sob, SOB_VIDEO, videoOid, &videoBson)) {

      mrjsonStartObject(context, "video");
      printJsonVideo(context, videoBson);
      mrjsonEndObject(context);

   } else {
      mrjsonNullAttribute(context, "video");
   }


   bson_oid_t conversationOid;
   bson *conversationBson;

   if (mrbsonFindOid(frame, "c", &conversationOid) &&
       sobGetBsonByOid(sob, SOB_CONVERSATION, conversationOid, &conversationBson)) {

      mrjsonStartObject(context, "conversation");
      printJsonConversation(context, conversationBson);
      mrjsonEndObject(context);

   } else {
      mrjsonNullAttribute(context, "conversation");
   }
}

void printJsonDashboardEntry(sobContext sob, mrjsonContext context, bson *dbEntry)
{
   mrbsonOidAttribute(context, dbEntry, "_id", "id"); 
   mrbsonIntAttribute(context, dbEntry, "e", "action");
   mrbsonOidAttribute(context, dbEntry, "f", "actor_id"); 

   // TODO : what should we do about this? 
   mrjsonNullAttribute(context, "read");

   bson_oid_t frameOid;
   bson *frameBson;

   if (mrbsonFindOid(dbEntry, "c", &frameOid) &&
       sobGetBsonByOid(sob, SOB_FRAME, frameOid, &frameBson)) {

      mrjsonStartObject(context, "frame");
      printJsonFrame(sob, context, frameBson);
      mrjsonEndObject(context);

   } else {
      mrjsonNullAttribute(context, "frame");
   }
}

void printJsonOutput(sobContext sob)
{
   mrjsonContext context = mrjsonAllocContext(true);
   
   mrjsonStartResponse(context); 

   mrjsonIntAttribute(context, "status", 200);
   mrjsonStartArray(context, "result");

   vector<bson *> dashboardEntries;

   sobGetBsonVector(sob, SOB_DASHBOARD_ENTRY, dashboardEntries);

   for (vector<bson *>::const_reverse_iterator iter = dashboardEntries.rbegin();
        iter != dashboardEntries.rend();
        ++iter) {

      mrjsonStartObject(context);
      printJsonDashboardEntry(sob, context, *iter);
      mrjsonEndObject(context);
   } 

   mrjsonEndArray(context);

   mrjsonIntAttribute(context, "cApiTimeMs", timeSinceMS(beginTime));

   mrjsonEndResponse(context);

   mrjsonPrintContext(context);
   mrjsonFreeContext(context);
}

bool loadData(sobContext sob)
{
   bson_oid_t userOid;

   cout << "Calling sobGetUniqueOidByStringField" << endl;

   userOid = sobGetUniqueOidByStringField(sob, SOB_USER, SOB_USER_DOWNCASE_NICKNAME, options.user);

   cout << "userOid = " << mrbsonOidString(&userOid) << endl;

   // TODO: if invalid userOid, status = 1, cleanup
   cout << "Calling sobLoadAllByOidField" << endl;
   sobLoadAllByOidField(sob,
                        SOB_DASHBOARD_ENTRY, 
                        SOB_DASHBOARD_ENTRY_USER_ID,
                        userOid,
                        options.limit,
                        options.skip,
                        -1);
   
   vector<bson_oid_t> frameOids;

   cout << "Calling sobGetOidVectorFromObjectField" << endl;
   sobGetOidVectorFromObjectField(sob, SOB_DASHBOARD_ENTRY, SOB_DASHBOARD_ENTRY_FRAME_ID, frameOids);
   cout << "Calling sobLoadAllById" << endl;
   sobLoadAllById(sob, SOB_FRAME, frameOids);

   vector<bson_oid_t> rollOids;
   sobGetOidVectorFromObjectField(sob, SOB_FRAME, SOB_FRAME_ROLL_ID, rollOids);
   sobLoadAllById(sob, SOB_ROLL, rollOids);

   vector<bson_oid_t> userOids;
   sobGetOidVectorFromObjectField(sob, SOB_FRAME, SOB_FRAME_CREATOR_ID, userOids);
   sobLoadAllById(sob, SOB_USER, userOids);
 
   vector<bson_oid_t> videoOids;
   sobGetOidVectorFromObjectField(sob, SOB_FRAME, SOB_FRAME_VIDEO_ID, videoOids);
   sobLoadAllById(sob, SOB_VIDEO, videoOids);
   
   vector<bson_oid_t> conversationOids;
   sobGetOidVectorFromObjectField(sob, SOB_FRAME, SOB_FRAME_CONVERSATION_ID, conversationOids);
   sobLoadAllById(sob, SOB_FRAME, conversationOids);

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
