#include <iostream>
#include <sstream>
#include <string>
#include <map>

#include "lib/mongo-c-driver/src/mongo.h"
#include "lib/mrbson/mrbson.h"

#include "sob.h"
#include "sobDatabases.h"
#include "sobProperties.h"

using namespace std;

#define ISREPLSET(a,b,c,d,e,f,g,h,i) d,
static bool sobIsReplSetConnection[] =
   { ALL_DATABASES(ISREPLSET) };
#undef ISREPLSET

#define REPLSETNAME(a,b,c,d,e,f,g,h,i) #e,
static const char *sobReplSetName[] =
   { ALL_DATABASES(REPLSETNAME) };
#undef REPLSETNAME

#define PRIMARYSERVER(a,b,c,d,e,f,g,h,i) #f,
static const char *sobPrimaryServer[] = 
   { ALL_DATABASES(PRIMARYSERVER) };
#undef PRIMARYSERVER

#define SECONDARYSERVER(a,b,c,d,e,f,g,h,i) #g,
static const char *sobSecondaryServer[] =
   { ALL_DATABASES(SECONDARYSERVER) };
#undef SECONDARYSERVER

#define DBUSER(a,b,c,d,e,f,g,h,i) #h,
static const char *sobDBUser[] =
   { ALL_DATABASES(DBUSER) };
#undef DBUSER

#define DBPASSWORD(a,b,c,d,e,f,g,h,i) #i,
static const char *sobDBPassword[] =
   { ALL_DATABASES(DBPASSWORD) };
#undef DBPASSWORD

#define DBCOLLECTION(a,b,c,d,e,f,g,h,i) #b "." #c,
static const char *sobDBCollection[] =
   { ALL_DATABASES(DBCOLLECTION) };
#undef DBCOLLECTION 

#define DBNAME(a,b,c,d,e,f,g,h,i) #b
static const char *sobDBName[] =
   { ALL_DATABASES(DBNAME) };
#undef DBNAME

#define FIELD_DB_NAME(a,b,c,d,e) #e,
static const char *sobFieldDBName[] =
   { ALL_PROPERTIES(FIELD_DB_NAME) };
#undef FIELD_DB_NAME

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

struct sobContextStruct
{
   sobEnvironment env;

   mongo *allocatedConn[SOB_NUMTYPES];
   mongo *typeToConn[SOB_NUMTYPES];
};

sobContext sobAllocContext(sobEnvironment env)
{
   sobContext toReturn = (sobContextStruct *)malloc(sizeof(sobContextStruct));
   memset(toReturn, 0, sizeof(struct sobContextStruct));

   toReturn->env = env;

   return toReturn;
}

void sobFreeContext(sobContext context)
{
   for (unsigned int i = 0 ; i < SOB_NUMTYPES ; i++) {
      if (context->allocatedConn[i] != NULL) {
         mongo_destroy(context->allocatedConn[i]); 
         free(context->allocatedConn[i]);
      }
   }

   free(context);
}

unsigned int sobArrayIndex(sobType type, sobEnvironment env)
{
   return ((unsigned int)type * SOB_NUMENVIRONMENTS) + (unsigned int)env;
}

bool sobTypesUseSameServer(sobType type1, sobType type2, sobEnvironment env)
{
   unsigned int type1Index = sobArrayIndex(type1, env);
   unsigned int type2Index = sobArrayIndex(type2, env);

   return (strcmp(sobPrimaryServer[type1Index], sobPrimaryServer[type2Index]) == 0)

          &&

          (
              (sobIsReplSetConnection[type1Index] &&
               sobIsReplSetConnection[type2Index] &&
               strcmp(sobSecondaryServer[type1Index], sobSecondaryServer[type2Index]) == 0)

                 ||

              (!sobIsReplSetConnection[type1Index] &&
               !sobIsReplSetConnection[type2Index])
          );
}

/*
 * For now, at initialization, we'll just connect to all databases;
 * later, we should lazily connect.
 */
bool sobConnect(sobContext context)
{
   for (sobType i = (sobType)0 ; i < SOB_NUMTYPES ; i = (sobType)((unsigned int)i + 1)) {
      bool previousConnectionExists = false;
      bool isReplSet = sobIsReplSetConnection[sobArrayIndex(i, context->env)];

      for (sobType j = (sobType)0 ; j < i; j = (sobType)((unsigned int)j + 1)) {
         // if 2 types need the exact same conn, don't allocate a duplicate connection
         if (sobTypesUseSameServer(i, j, context->env)) {
            previousConnectionExists = true;
            context->typeToConn[i] = context->typeToConn[j];
            break;
         }
      }

      // don't need to set up any new connections if a previous connection existed
      if (previousConnectionExists) {
         continue;
      }

      context->allocatedConn[i] = (mongo *)malloc(sizeof(mongo));
      context->typeToConn[i] = context->allocatedConn[i];

      int status;

      if (isReplSet) {
         mongo_host_port primary;
         mongo_host_port secondary;

         mongo_replset_init(context->allocatedConn[i],
                            sobReplSetName[sobArrayIndex(i, context->env)]);

         mongo_parse_host(sobPrimaryServer[sobArrayIndex(i, context->env)], &primary);
         mongo_parse_host(sobSecondaryServer[sobArrayIndex(i, context->env)] , &secondary);

         mongo_replset_add_seed(context->allocatedConn[i], primary.host, primary.port);
         mongo_replset_add_seed(context->allocatedConn[i], secondary.host, secondary.port);

         status = mongo_replset_connect(context->allocatedConn[i]);

      } else {
         mongo_host_port primary;

         mongo_init(context->allocatedConn[i]);
         mongo_parse_host(sobPrimaryServer[sobArrayIndex(i, context->env)], &primary);

         status = mongo_connect(context->allocatedConn[i], primary.host, primary.port);            
      }

      if (MONGO_OK != status) {
         switch (context->allocatedConn[i]->err) {
            case MONGO_CONN_SUCCESS:    printf("mongo connected\n"); break;
            case MONGO_CONN_NO_SOCKET:  printf("no socket\n"); return false;
            case MONGO_CONN_FAIL:       printf("connection failed\n"); return false;
            case MONGO_CONN_NOT_MASTER: printf("not master\n"); return false;
            default:                    printf("received unknown status\n"); return false;
         }
      } else {
         printf("mongo connected\n");
      }

   }     
     
   return true;
}

bool sobAuthenticate(sobContext context, sobType type)
{
   if (strcmp(sobDBUser[sobArrayIndex(type, context->env)], "") != 0 &&
       strcmp(sobDBPassword[sobArrayIndex(type, context->env)], "") != 0) {

      int status;

      status = mongo_cmd_authenticate(context->allocatedConn[type],
                                      sobDBName[sobArrayIndex(type, context->env)],
                                      sobDBUser[sobArrayIndex(type, context->env)],
                                      sobDBPassword[sobArrayIndex(type, context->env)]);

      if (MONGO_OK != status) {
         switch (context->allocatedConn[type]->err) {
            case MONGO_CONN_SUCCESS:    printf("mongo authenticated\n"); break;
            case MONGO_CONN_NO_SOCKET:  printf("no socket\n"); return false;
            case MONGO_CONN_FAIL:       printf("connection failed\n"); return false;
            case MONGO_CONN_NOT_MASTER: printf("not master\n"); return false;
            default:                    printf("received unknown status\n"); return false;
         }
      } else {
         printf("mongo authenticated\n");
      }
   }

   return true;
}

bson_oid_t sobGetUniqueOidByStringField(sobContext context,
                                   sobType type,
                                   sobField field,
                                   const string &value)
{
   bson_oid_t result;

   bson query;
   bson_init(&query);
   bson_append_string(&query, sobFieldDBName[field], value.c_str());
   bson_finish(&query);
   
   bson fields;
   bson_init(&fields);
   bson_append_int(&fields, "_id", 1);
   bson_finish(&fields);
   
   bson out;
   bson_init(&out);

   // TODO: check return status
   sobAuthenticate(context, type);

   if (mongo_find_one(context->typeToConn[type], 
                      sobDBCollection[sobArrayIndex(type, context->env)],
                      &query, 
                      &fields, 
                      &out) == MONGO_OK)
   {
      bson_iterator iterator;
      bson_iterator_init(&iterator, &out);
      result = *bson_iterator_oid(&iterator);
   } 
   
   bson_destroy(&out);
   bson_destroy(&fields);
   bson_destroy(&query);

   return result; 
}

void sobLoadAllByOidField(sobContext context,
                          sobType type,
                          sobField field,
                          bson_oid_t oid,
			  unsigned int limit,
                          unsigned int skip,
                          int order)
{
   bson query;
   bson_init(&query);
   bson_append_start_object(&query, "$query");
     bson_append_oid(&query, "a", &oid);
   bson_append_finish_object(&query);
   if (order != 0) {
      bson_append_start_object(&query, "$orderby");
        bson_append_int(&query, "_id", order);
      bson_append_finish_object(&query);
   }
   bson_finish(&query);
  
   // TODO: check return status
   sobAuthenticate(context, type);
 
   mongo_cursor cursor;
   mongo_cursor_init(&cursor, 
                     context->typeToConn[type],
                     sobDBCollection[sobArrayIndex(type, context->env)]);

   mongo_cursor_set_query(&cursor, &query);

   if (limit != 0) {
      mongo_cursor_set_limit(&cursor, limit);
   }
   if (skip != 0) {
      mongo_cursor_set_skip(&cursor, skip);
   }
   
   while (mongo_cursor_next(&cursor) == MONGO_OK) {
     bson_iterator iterator;
     //if (bson_find(&iterator, mongo_cursor_bson(&cursor), "c" )) {
     //	framesToLoad.push_back(*bson_iterator_oid(&iterator));
     //}
     if (bson_find(&iterator, mongo_cursor_bson(&cursor), "_id" )) {

        bson *newValue = (bson *)malloc(sizeof(bson));
        bson_copy(newValue, mongo_cursor_bson(&cursor));

        string newKey = mrbsonOidString(bson_iterator_oid(&iterator));

        //dashboardEntries.insert(pair<string, bson *>(newKey, newValue));
     }
   }

  bson_destroy(&query);
  mongo_cursor_destroy(&cursor);
}

void sobLoadAllById(sobContext context,
                    sobType type,
                    const vector<bson_oid_t> &oids)
{
   bson query;
   bson_init(&query);
   bson_append_start_object(&query, "_id");
   bson_append_start_array(&query, "$in");

   for (unsigned int i = 0; i < oids.size(); i++) {
     ostringstream stringStream;
     stringStream << i;

     bson_append_oid(&query, stringStream.str().c_str(), &oids[i]);
   }

   bson_append_finish_array(&query);
   bson_append_finish_object(&query);
   bson_finish(&query);
 
   // TODO: check return status
   sobAuthenticate(context, type);
 
   mongo_cursor cursor;
   mongo_cursor_init(&cursor,
                     context->typeToConn[type], 
                     sobDBCollection[sobArrayIndex(type, context->env)]);
   mongo_cursor_set_query(&cursor, &query);
   
   while (mongo_cursor_next(&cursor) == MONGO_OK) {
      bson_iterator iterator;
//      if (bson_find(&iterator, mongo_cursor_bson(&cursor), "a" )) {
//      	rollsToLoad.push_back(*bson_iterator_oid(&iterator));
//      }
//      if (bson_find(&iterator, mongo_cursor_bson(&cursor), "d" )) {
//      	usersToLoad.push_back(*bson_iterator_oid(&iterator));
//      }
//      if (bson_find(&iterator, mongo_cursor_bson(&cursor), "c" )) {
//      	conversationsToLoad.push_back(*bson_iterator_oid(&iterator));
//      }
//      if (bson_find(&iterator, mongo_cursor_bson(&cursor), "b" )) {
//      	videosToLoad.push_back(*bson_iterator_oid(&iterator));
//      }
      if (bson_find(&iterator, mongo_cursor_bson(&cursor), "_id" )) {

         bson *newValue = (bson *)malloc(sizeof(bson));
         bson_copy(newValue, mongo_cursor_bson(&cursor));

         string newKey = mrbsonOidString(bson_iterator_oid(&iterator));

   //      frames.insert(pair<string, bson *>(newKey, newValue));
      }

   }
   
   bson_destroy(&query);
   mongo_cursor_destroy(&cursor);
}

bool sobGetBsonByOid(sobContext context,
                     sobType type,
                     bson_oid_t oid,
                     bson **result)
{
   return false;
}

bool sobGetBsonVector(sobContext context,
                      sobType type,
                      std::vector<bson *> &result)
{
   return false;
}

bool sobGetOidVectorFromObjectField(sobContext context,
                                    sobType type,
                                    sobField field,
                                    vector<bson_oid_t> &result)
{
   return false;
}



