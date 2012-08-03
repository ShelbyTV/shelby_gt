#include <fstream>
#include <iostream>
#include <string>
#include <set>
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

using namespace std;

static struct Options {
	string user;
	int limit;
} options;

static mongo conn;

bson_oid_t userId;

vector<bson_oid_t> frames;
vector<bson_oid_t> rolls;
vector<bson_oid_t> users;
vector<bson_oid_t> videos;
vector<bson_oid_t> conversations;

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
		cout << "User ID in mongo is: " << endl;
		bson_print(&out);
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
	bson_append_oid(&query, "a", &userId); // user_id
	bson_finish(&query);

	mongo_cursor cursor;
	mongo_cursor_init(&cursor, &conn, "dev-gt-dashboard-entry.dashboard_entries");
	mongo_cursor_set_query(&cursor, &query);
        mongo_cursor_set_limit(&cursor, options.limit);

	while (mongo_cursor_next(&cursor) == MONGO_OK) {
		bson_iterator iterator;
		bson_print(mongo_cursor_bson(&cursor));
		if (bson_find(&iterator, mongo_cursor_bson(&cursor), "c" )) {
			frames.push_back(*bson_iterator_oid(&iterator));
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

   for (unsigned int i = 0; i < frames.size(); i++) {
     ostringstream stringStream;
     stringStream << i;

     bson_append_oid(&query, stringStream.str().c_str(), &frames[i]);
   }

   bson_append_finish_array(&query);
   bson_append_finish_object(&query);
   bson_finish(&query);
  
   mongo_cursor cursor;
   mongo_cursor_init(&cursor, &conn, "dev-gt-roll-frame.frames");
   mongo_cursor_set_query(&cursor, &query);
   
   while (mongo_cursor_next(&cursor) == MONGO_OK) {
		bson_iterator iterator;
		bson_print(mongo_cursor_bson(&cursor));
		if (bson_find(&iterator, mongo_cursor_bson(&cursor), "a" )) {
			rolls.push_back(*bson_iterator_oid(&iterator));
		}
        	if (bson_find(&iterator, mongo_cursor_bson(&cursor), "d" )) {
			users.push_back(*bson_iterator_oid(&iterator));
		}
        	if (bson_find(&iterator, mongo_cursor_bson(&cursor), "c" )) {
			conversations.push_back(*bson_iterator_oid(&iterator));
		}
        	if (bson_find(&iterator, mongo_cursor_bson(&cursor), "b" )) {
			videos.push_back(*bson_iterator_oid(&iterator));
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

   for (unsigned int i = 0; i < rolls.size(); i++) {
     ostringstream stringStream;
     stringStream << i;

     bson_append_oid(&query, stringStream.str().c_str(), &rolls[i]);
   }

   bson_append_finish_array(&query);
   bson_append_finish_object(&query);
   bson_finish(&query);
  
   mongo_cursor cursor;
   mongo_cursor_init(&cursor, &conn, "dev-gt-roll-frame.rolls");
   mongo_cursor_set_query(&cursor, &query);
   
   while (mongo_cursor_next(&cursor) == MONGO_OK) {
		bson_print(mongo_cursor_bson(&cursor));
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

   for (unsigned int i = 0; i < users.size(); i++) {
     ostringstream stringStream;
     stringStream << i;

     bson_append_oid(&query, stringStream.str().c_str(), &users[i]);
   }

   bson_append_finish_array(&query);
   bson_append_finish_object(&query);
   bson_finish(&query);
  
   mongo_cursor cursor;
   mongo_cursor_init(&cursor, &conn, "dev-gt-user.users");
   mongo_cursor_set_query(&cursor, &query);
   
   while (mongo_cursor_next(&cursor) == MONGO_OK) {
		bson_print(mongo_cursor_bson(&cursor));
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

   for (unsigned int i = 0; i < videos.size(); i++) {
     ostringstream stringStream;
     stringStream << i;

     bson_append_oid(&query, stringStream.str().c_str(), &videos[i]);
   }

   bson_append_finish_array(&query);
   bson_append_finish_object(&query);
   bson_finish(&query);
  
   mongo_cursor cursor;
   mongo_cursor_init(&cursor, &conn, "dev-gt-video.videos");
   mongo_cursor_set_query(&cursor, &query);
   
   while (mongo_cursor_next(&cursor) == MONGO_OK) {
		bson_print(mongo_cursor_bson(&cursor));
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

   for (unsigned int i = 0; i < conversations.size(); i++) {
     ostringstream stringStream;
     stringStream << i;

     bson_append_oid(&query, stringStream.str().c_str(), &conversations[i]);
   }

   bson_append_finish_array(&query);
   bson_append_finish_object(&query);
   bson_finish(&query);
  
   mongo_cursor cursor;
   mongo_cursor_init(&cursor, &conn, "dev-gt-conversation.conversations");
   mongo_cursor_set_query(&cursor, &query);
   
   while (mongo_cursor_next(&cursor) == MONGO_OK) {
		bson_print(mongo_cursor_bson(&cursor));
   }
   
   bson_destroy(&query);
   mongo_cursor_destroy(&cursor);
}

//void updateItemInMongoWithRecs(const unsigned int item, vector<Recommendation> &recs)
//{
//   bson cond; 
//   bson_init(&cond);
//   bson_append_oid(&cond, "_id", &gtVideos[item].mongoId);
//   bson_finish(&cond);
//   
//   bson op;
//   bson_init(&op);
//   {
//       bson_append_start_object(&op, "$set");
//       bson_append_start_array(&op, "r"); 
//       
//       for (unsigned int i = 0; i < recs.size(); i++) {
//         ostringstream stringStream;
//         stringStream << i;
//
//         bson_append_start_object(&op, stringStream.str().c_str());
//         bson_append_oid(&op, "a", &gtVideos[recs[i].recId].mongoId);
//         bson_append_double(&op, "b", recs[i].recVal);
//         bson_append_finish_object(&op);
//       }
//
//       bson_append_finish_array(&op);
//       bson_append_finish_object(&op);
//   }
//   bson_finish(&op);
//  
//   throttle.throttle(); 
//   int status = mongo_update(&conn, "gt-video.videos", &cond, &op, 0);
//   if (status != MONGO_OK) {
//      cout << "ERROR updating video." << endl;
//   }
 
   // bson_print(&cond); 
   // bson_print(&op);
 
//   bson_destroy(&op);
//   bson_destroy(&cond);
// }

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

void timeSince(struct timeval begin)
{
   struct timeval currentTime;
   gettimeofday(&currentTime, NULL);

   struct timeval difference;
   timersub(&currentTime, &begin, &difference);

   cout << "Time: " << difference.tv_sec << "s, " << (difference.tv_usec / 1000) << "ms" << endl;
}

int main(int argc, char **argv)
{
   struct timeval beginTime;
   gettimeofday(&beginTime, NULL);

   int status = 0;

   setDefaultOptions();
   parseUserOptions(argc, argv);

   if (!connectToMongo()) {
      status = 1;
      goto mongoCleanup;
   } 

   timeSince(beginTime);
   cout << "Connected to mongo." << endl;

   loadUserIdByNickname();
   loadDashboardEntries();
   loadFrames();
   loadRolls();
   loadUsers();
   loadVideos();
   loadConversations();

   // loadVideoMap(options.videoMapFile);

   // cout << "Video map loaded." << endl;

   // gtVideos.resize(recVideoIDs.size());

   // addOrUpdateRecommendations(options.outputFile); 

   // printVideoStats();
   // printMissingVideos();

mongoCleanup:
   mongo_destroy(&conn);

   timeSince(beginTime);
   return status;
}
