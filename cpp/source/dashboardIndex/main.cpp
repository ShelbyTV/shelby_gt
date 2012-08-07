#include <fstream>
#include <iostream>
#include <string>
#include <map>
#include <vector>
#include <sstream>
#include <limits>

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

using namespace std;

static struct Options {
	string user;
	int limit;
} options;

mongo conn;
struct timeval beginTime;

bson_oid_t userId;

map<string, bson *> dashboardEntries;
map<string, bson *> frames;
map<string, bson *> users;
map<string, bson *> rolls;
map<string, bson *> videos;
map<string, bson *> conversations;

vector<bson_oid_t> framesToLoad;
vector<bson_oid_t> rollsToLoad;
vector<bson_oid_t> usersToLoad;
vector<bson_oid_t> videosToLoad;
vector<bson_oid_t> conversationsToLoad;

void printHelpText()
{
   cout << "dashboardIndex usage:" << endl;
   cout << "   -h --help        Print this help message" << endl;
   cout << "   -u --user        Lowercase nickname of user" << endl;
   cout << "   -l --limit       Limit to this number of dashboard entries" << endl;
}

bool connectToMongo()
{
   mongo_init(&conn);
   
   int status = mongo_connect(&conn, "127.0.0.1", 27017);
   
   if (MONGO_OK != status) {
      switch (conn.err) {
         case MONGO_CONN_SUCCESS:    break;
         case MONGO_CONN_NO_SOCKET:  printf("no socket\n"); return false;
         case MONGO_CONN_FAIL:       printf("connection failed\n"); return false;
         case MONGO_CONN_NOT_MASTER: printf("not master\n"); return false;
         default:                    printf("received unknown status\n"); return false;
      }
   }
   
   return true;
}

void loadUserIdByNickname()
{
   bson query;
   bson_init(&query);
   bson_append_string(&query, "downcase_nickname", options.user.c_str());
   bson_finish(&query);
   
   bson fields;
   bson_init(&fields);
   bson_append_int(&fields, "_id", 1);
   bson_finish(&fields);
   
   bson out;
   bson_init(&out);
   
   if (mongo_find_one(&conn, "dev-gt-user.users", &query, &fields, &out) == MONGO_OK) {
      bson_iterator iterator;
      bson_iterator_init(&iterator, &out);
      userId = *bson_iterator_oid(&iterator);
   } else {
      cout << "Error querying for user." << endl;
   }
   
   bson_destroy(&out);
   bson_destroy(&fields);
   bson_destroy(&query);
}

void loadDashboardEntries()
{
   bson query;
   bson_init(&query);
   bson_append_start_object(&query, "$query");
     bson_append_oid(&query, "a", &userId); // user_id
   bson_append_finish_object(&query);
   bson_append_start_object(&query, "$orderby");
     bson_append_int(&query, "_id", -1);
   bson_append_finish_object(&query);
   bson_finish(&query);
   
   mongo_cursor cursor;
   mongo_cursor_init(&cursor, &conn, "dev-gt-dashboard-entry.dashboard_entries");
   mongo_cursor_set_query(&cursor, &query);
   mongo_cursor_set_limit(&cursor, options.limit);
   
   while (mongo_cursor_next(&cursor) == MONGO_OK) {
     bson_iterator iterator;
     if (bson_find(&iterator, mongo_cursor_bson(&cursor), "c" )) {
     	framesToLoad.push_back(*bson_iterator_oid(&iterator));
     }
     if (bson_find(&iterator, mongo_cursor_bson(&cursor), "_id" )) {

        bson *newValue = (bson *)malloc(sizeof(bson));
        bson_copy(newValue, mongo_cursor_bson(&cursor));

        string newKey = mrbsonOidString(bson_iterator_oid(&iterator));

        dashboardEntries.insert(pair<string, bson *>(newKey, newValue));
     }
   }

  bson_destroy(&query);
  mongo_cursor_destroy(&cursor);
}

void loadFrames()
{
   bson query;
   bson_init(&query);
   bson_append_start_object(&query, "_id");
   bson_append_start_array(&query, "$in");

   for (unsigned int i = 0; i < framesToLoad.size(); i++) {
     ostringstream stringStream;
     stringStream << i;

     bson_append_oid(&query, stringStream.str().c_str(), &framesToLoad[i]);
   }

   bson_append_finish_array(&query);
   bson_append_finish_object(&query);
   bson_finish(&query);
  
   mongo_cursor cursor;
   mongo_cursor_init(&cursor, &conn, "dev-gt-roll-frame.frames");
   mongo_cursor_set_query(&cursor, &query);
   
   while (mongo_cursor_next(&cursor) == MONGO_OK) {
      bson_iterator iterator;
      if (bson_find(&iterator, mongo_cursor_bson(&cursor), "a" )) {
      	rollsToLoad.push_back(*bson_iterator_oid(&iterator));
      }
      if (bson_find(&iterator, mongo_cursor_bson(&cursor), "d" )) {
      	usersToLoad.push_back(*bson_iterator_oid(&iterator));
      }
      if (bson_find(&iterator, mongo_cursor_bson(&cursor), "c" )) {
      	conversationsToLoad.push_back(*bson_iterator_oid(&iterator));
      }
      if (bson_find(&iterator, mongo_cursor_bson(&cursor), "b" )) {
      	videosToLoad.push_back(*bson_iterator_oid(&iterator));
      }
      if (bson_find(&iterator, mongo_cursor_bson(&cursor), "_id" )) {

         bson *newValue = (bson *)malloc(sizeof(bson));
         bson_copy(newValue, mongo_cursor_bson(&cursor));

         string newKey = mrbsonOidString(bson_iterator_oid(&iterator));

         frames.insert(pair<string, bson *>(newKey, newValue));
      }

   }
   
   bson_destroy(&query);
   mongo_cursor_destroy(&cursor);
}

void loadRolls()
{
   bson query;
   bson_init(&query);
   bson_append_start_object(&query, "_id");
   bson_append_start_array(&query, "$in");

   for (unsigned int i = 0; i < rollsToLoad.size(); i++) {
     ostringstream stringStream;
     stringStream << i;

     bson_append_oid(&query, stringStream.str().c_str(), &rollsToLoad[i]);
   }

   bson_append_finish_array(&query);
   bson_append_finish_object(&query);
   bson_finish(&query);
  
   mongo_cursor cursor;
   mongo_cursor_init(&cursor, &conn, "dev-gt-roll-frame.rolls");
   mongo_cursor_set_query(&cursor, &query);
   
   while (mongo_cursor_next(&cursor) == MONGO_OK) {
      bson_iterator iterator;
      if (bson_find(&iterator, mongo_cursor_bson(&cursor), "_id" )) {

        bson *newValue = (bson *)malloc(sizeof(bson));
        bson_copy(newValue, mongo_cursor_bson(&cursor));

        string newKey = mrbsonOidString(bson_iterator_oid(&iterator));

        rolls.insert(pair<string, bson *>(newKey, newValue));
     }
   }
   
   bson_destroy(&query);
   mongo_cursor_destroy(&cursor);
}

void loadUsers()
{
   bson query;
   bson_init(&query);
   bson_append_start_object(&query, "_id");
   bson_append_start_array(&query, "$in");

   for (unsigned int i = 0; i < usersToLoad.size(); i++) {
     ostringstream stringStream;
     stringStream << i;

     bson_append_oid(&query, stringStream.str().c_str(), &usersToLoad[i]);
   }

   bson_append_finish_array(&query);
   bson_append_finish_object(&query);
   bson_finish(&query);
  
   mongo_cursor cursor;
   mongo_cursor_init(&cursor, &conn, "dev-gt-user.users");
   mongo_cursor_set_query(&cursor, &query);
   
   while (mongo_cursor_next(&cursor) == MONGO_OK) {
      bson_iterator iterator;
      if (bson_find(&iterator, mongo_cursor_bson(&cursor), "_id" )) {

         bson *newValue = (bson *)malloc(sizeof(bson));
         bson_copy(newValue, mongo_cursor_bson(&cursor));

         string newKey = mrbsonOidString(bson_iterator_oid(&iterator));

         users.insert(pair<string, bson *>(newKey, newValue));
     }
   }
   
   bson_destroy(&query);
   mongo_cursor_destroy(&cursor);
}

void loadVideos()
{
   bson query;
   bson_init(&query);
   bson_append_start_object(&query, "_id");
   bson_append_start_array(&query, "$in");

   for (unsigned int i = 0; i < videosToLoad.size(); i++) {
     ostringstream stringStream;
     stringStream << i;

     bson_append_oid(&query, stringStream.str().c_str(), &videosToLoad[i]);
   }

   bson_append_finish_array(&query);
   bson_append_finish_object(&query);
   bson_finish(&query);
  
   mongo_cursor cursor;
   mongo_cursor_init(&cursor, &conn, "dev-gt-video.videos");
   mongo_cursor_set_query(&cursor, &query);
   
   while (mongo_cursor_next(&cursor) == MONGO_OK) {
      bson_iterator iterator;
      if (bson_find(&iterator, mongo_cursor_bson(&cursor), "_id" )) {

         bson *newValue = (bson *)malloc(sizeof(bson));
         bson_copy(newValue, mongo_cursor_bson(&cursor));

         string newKey = mrbsonOidString(bson_iterator_oid(&iterator));

         videos.insert(pair<string, bson *>(newKey, newValue));
      }
   }
   
   bson_destroy(&query);
   mongo_cursor_destroy(&cursor);
}

void loadConversations()
{
   bson query;
   bson_init(&query);
   bson_append_start_object(&query, "_id");
   bson_append_start_array(&query, "$in");

   for (unsigned int i = 0; i < conversationsToLoad.size(); i++) {
     ostringstream stringStream;
     stringStream << i;

     bson_append_oid(&query, stringStream.str().c_str(), &conversationsToLoad[i]);
   }

   bson_append_finish_array(&query);
   bson_append_finish_object(&query);
   bson_finish(&query);
  
   mongo_cursor cursor;
   mongo_cursor_init(&cursor, &conn, "dev-gt-conversation.conversations");
   mongo_cursor_set_query(&cursor, &query);
   
   while (mongo_cursor_next(&cursor) == MONGO_OK) {
      bson_iterator iterator;
      if (bson_find(&iterator, mongo_cursor_bson(&cursor), "_id" )) {

         bson *newValue = (bson *)malloc(sizeof(bson));
         bson_copy(newValue, mongo_cursor_bson(&cursor));

         string newKey = mrbsonOidString(bson_iterator_oid(&iterator));

         conversations.insert(pair<string, bson *>(newKey, newValue));
      }
   }
   
   bson_destroy(&query);
   mongo_cursor_destroy(&cursor);
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
         {0, 0, 0, 0}
      };
      
      int option_index = 0;
      c = getopt_long(argc, argv, "hu:l:", long_options, &option_index);
   
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
}

unsigned int timeSinceMS(struct timeval begin)
{
   struct timeval currentTime;
   gettimeofday(&currentTime, NULL);

   struct timeval difference;
   timersub(&currentTime, &begin, &difference);

   return difference.tv_sec * 1000 + (difference.tv_usec / 1000); 
}

void printJsonMessage(mrjsonContext *context, bson *message)
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

   // TODO: created_at
   mrjsonStringAttribute(context, "created_at", "");
}

void printJsonConversation(mrjsonContext *context, bson *conversation)
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
      printJsonMessage(context, &message);
   }

   mrjsonEndArray(context); 
}

void printJsonVideo(mrjsonContext *context, bson *video)
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

void printJsonRoll(mrjsonContext *context, bson *roll)
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

void printJsonUser(mrjsonContext *context, bson *user)
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

void printJsonFrame(mrjsonContext *context, bson *frame)
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

   // TODO: created_at
   mrjsonNullAttribute(context, "created_at");


   string creatorOid;
   map<string, bson *>::const_iterator creatorBson;

   if (mrbsonFindOid(frame, "d", creatorOid) &&
       (creatorBson = users.find(creatorOid)) != users.end()) {

      mrjsonStartObject(context, "creator");
      printJsonUser(context, creatorBson->second);
      mrjsonEndObject(context);

   } else {
      mrjsonNullAttribute(context, "creator");
   }


   // TODO: upvote_users
   mrjsonEmptyArrayAttribute(context, "upvote_users");


   string rollOid;
   map<string, bson *>::const_iterator rollBson;

   if (mrbsonFindOid(frame, "a", rollOid) &&
       (rollBson = rolls.find(rollOid)) != rolls.end()) {

      mrjsonStartObject(context, "roll");
      printJsonRoll(context, rollBson->second);
      mrjsonEndObject(context);

   } else {
      mrjsonNullAttribute(context, "roll");
   }


   string videoOid;
   map<string, bson *>::const_iterator videoBson;

   if (mrbsonFindOid(frame, "b", videoOid) &&
       (videoBson = videos.find(videoOid)) != videos.end()) {

      mrjsonStartObject(context, "video");
      printJsonVideo(context, videoBson->second);
      mrjsonEndObject(context);

   } else {
      mrjsonNullAttribute(context, "video");
   }


   string conversationOid;
   map<string, bson *>::const_iterator conversationBson;

   if (mrbsonFindOid(frame, "c", conversationOid) &&
       (conversationBson = conversations.find(conversationOid)) != conversations.end()) {

      mrjsonStartObject(context, "conversation");
      printJsonConversation(context, conversationBson->second);
      mrjsonEndObject(context);

   } else {
      mrjsonNullAttribute(context, "conversation");
   }
}

void printJsonDashboardEntry(mrjsonContext *context, bson *dbEntry)
{
   mrbsonOidAttribute(context, dbEntry, "_id", "id"); 
   mrbsonIntAttribute(context, dbEntry, "e", "action");
   mrbsonOidAttribute(context, dbEntry, "f", "actor_id"); 

   // TODO : what should we do about this? 
   mrjsonNullAttribute(context, "read");

   string frameOid;
   map<string, bson *>::const_iterator frameBson;

   if (mrbsonFindOid(dbEntry, "c", frameOid) &&
       (frameBson = frames.find(frameOid)) != frames.end()) {

      mrjsonStartObject(context, "frame");
      printJsonFrame(context, frameBson->second);
      mrjsonEndObject(context);

   } else {
      mrjsonNullAttribute(context, "frame");
   }
}

void printJsonOutput()
{
   mrjsonContext context;
   mrjsonInitContext(&context);
   
   mrjsonSetPretty(&context, true);
   mrjsonStartResponse(&context); 

   mrjsonIntAttribute(&context, "status", 200);
   mrjsonStartArray(&context, "result");

   for (map<string, bson *>::const_iterator iter = dashboardEntries.begin();
        iter != dashboardEntries.end();
        ++iter) {

      mrjsonStartObject(&context);
      printJsonDashboardEntry(&context, iter->second);
      mrjsonEndObject(&context);
   } 

   mrjsonEndArray(&context);

   mrjsonIntAttribute(&context, "cApiTimeMs", timeSinceMS(beginTime));

   mrjsonEndResponse(&context);
}

int main(int argc, char **argv)
{
   gettimeofday(&beginTime, NULL);

   int status = 0;

   setDefaultOptions();
   parseUserOptions(argc, argv);

   if (!connectToMongo()) {
      status = 1;
      goto mongoCleanup;
   } 

   loadUserIdByNickname();
   loadDashboardEntries();
   loadFrames();
   loadRolls();
   loadUsers();
   loadVideos();
   loadConversations();

   printJsonOutput();

mongoCleanup:
   mongo_destroy(&conn);

   return status;
}
