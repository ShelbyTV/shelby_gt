#include <assert.h>
#include <sys/time.h>

#include "lib/mongo-c-driver/src/mongo.h"
#include "lib/mrjson/mrjson.h"
#include "lib/mrbson/mrbson.h"

using namespace std;

string mrbsonOidString(bson_oid_t *oid)
{
   char buffer[100]; // an oid is 24 hex chars + null byte, let's go big to ensure compatibility
  
   bson_oid_to_string(oid, buffer);
   return string(buffer); 
}

string oidConciseTimeAgoInWordsString(bson_oid_t *oid)
{
   time_t oidTime = bson_oid_generated_time(oid);
   struct timeval oidTimeVal;
   oidTimeVal.tv_sec = oidTime;
   oidTimeVal.tv_usec = 0;

   struct timeval currentTime;
   gettimeofday(&currentTime, NULL);

   struct timeval difference;
   timersub(&currentTime, &oidTimeVal, &difference);

   /*
    * future times => "just now"
    * < 1 minute => "just now"
    * 1m - 59m => "Xm"
    * 1h - 12h => "Xh"
    * > 12h => "MMM dd" (Feb 22 or Dec 1)
    */

    time_t minutes = (difference.tv_sec / 60);
   
    char buffer[100];

    if (minutes <= 1) {
       return "just now";
    } else if (minutes <= 59) {
       snprintf(buffer, 100, "%dm ago", (int)minutes);
    } else if (minutes <= 720) {
       snprintf(buffer, 100, "%dh ago", (int)minutes / 60);
    } else {
       struct tm *date = gmtime(&oidTime);
       strftime(buffer, 100, "%b %-d", date);
    }

    return string(buffer);
}

bool mrbsonFindOidString(bson *data,
                         const string &bsonField,
                         string &outputOidString)
{
   bson_iterator iterator;
   bson_type type;
 
   type = bson_find(&iterator, data, bsonField.c_str());
   if (type != BSON_OID) {
      return false;
   }

   outputOidString = mrbsonOidString(bson_iterator_oid(&iterator));
   return true;
}

bool mrbsonFindOid(bson *data,
                   const string &bsonField,
                   bson_oid_t *outputOid)
{
   bson_iterator iterator;
   bson_type type;
 
   type = bson_find(&iterator, data, bsonField.c_str());
   if (type != BSON_OID) {
      return false;
   }

   // possibly we should just return the reference instead of the copy?
   *outputOid = *bson_iterator_oid(&iterator);
   return true;
}

void mrbsonOidConciseTimeAgoAttribute(mrjsonContext context,
                                      bson *data, 
                                      const string &bsonField, 
                                      const string& outputName)
{
   bson_iterator iterator;
   bson_type type;
 
   type = bson_find(&iterator, data, bsonField.c_str());
   if (type == BSON_OID) {
     mrjsonStringAttribute(context, outputName.c_str(), oidConciseTimeAgoInWordsString(bson_iterator_oid(&iterator)).c_str());
   } else {
     mrjsonStringAttribute(context, outputName.c_str(), ""); 
   }
}


void mrbsonOidAttribute(mrjsonContext context,
                        bson *data, 
                        const string &bsonField, 
                        const string& outputName)
{
   bson_iterator iterator;
   bson_type type;
 
   type = bson_find(&iterator, data, bsonField.c_str());
   if (type == BSON_OID) {
     mrjsonStringAttribute(context, outputName.c_str(), mrbsonOidString(bson_iterator_oid(&iterator)).c_str());
   } else {
     mrjsonNullAttribute(context, outputName.c_str()); 
   }
}

void mrbsonIntAttribute(mrjsonContext context,
                        bson *data, 
                        const string &bsonField, 
                        const string& outputName)
{
   bson_iterator iterator;
   bson_type type;
 
   type = bson_find(&iterator, data, bsonField.c_str());
   if (type == BSON_INT) {
     mrjsonIntAttribute(context, outputName.c_str(), bson_iterator_int(&iterator));
   } else {
     mrjsonIntAttribute(context, outputName.c_str(), 0); 
   }
}

void mrbsonBoolAttribute(mrjsonContext context,
                         bson *data, 
                         const string &bsonField, 
                         const string& outputName)
{
   bson_iterator iterator;
   bson_type type;
 
   type = bson_find(&iterator, data, bsonField.c_str());
   if (type == BSON_BOOL) {
     mrjsonBoolAttribute(context, outputName.c_str(), bson_iterator_bool(&iterator));
   } else {
     mrjsonNullAttribute(context, outputName.c_str()); 
   }
}

void mrbsonDoubleAttribute(mrjsonContext context,
                           bson *data,
                           const string &bsonField,
                           const string& outputName)
{
   bson_iterator iterator;
   bson_type type;
 
   type = bson_find(&iterator, data, bsonField.c_str());
   if (type == BSON_DOUBLE) {
     mrjsonDoubleAttribute(context, outputName.c_str(), bson_iterator_double(&iterator));
   } else {
     mrjsonDoubleAttribute(context, outputName.c_str(), 0); 
   }
}

void mrbsonStringAttribute(mrjsonContext context,
                           bson *data,
                           const string &bsonField,
                           const string& outputName)
{
   bson_iterator iterator;
   bson_type type;
 
   type = bson_find(&iterator, data, bsonField.c_str());
   if (type == BSON_STRING) {
     mrjsonStringAttribute(context, outputName.c_str(), bson_iterator_string(&iterator));
   } else {
     mrjsonNullAttribute(context, outputName.c_str()); 
   }
}

void mrbsonSimpleArrayAttribute(mrjsonContext context,
                                bson *data,
                                const string &bsonField,
                                const string& outputName)
{
   bson array;
   bson_iterator iterator;
   bson_type type;

   type = bson_find(&iterator, data, bsonField.c_str());
   assert(type == BSON_ARRAY);

   bson_iterator_subobject(&iterator, &array);
   bson_iterator_from_buffer(&iterator, array.data);

   mrjsonStartArray(context, outputName.c_str());
   while ((type = bson_iterator_next(&iterator))) {
      switch (type) {
         case BSON_STRING:
            mrjsonStringArrayEntry(context, bson_iterator_string(&iterator));
            break;

         case BSON_EOO:
         case BSON_DOUBLE:
         case BSON_OBJECT:
         case BSON_ARRAY:
         case BSON_BINDATA:
         case BSON_UNDEFINED:
         case BSON_OID:
         case BSON_BOOL:
         case BSON_DATE:
         case BSON_NULL:
         case BSON_REGEX:
         case BSON_DBREF:
         case BSON_CODE:
         case BSON_SYMBOL:
         case BSON_CODEWSCOPE:
         case BSON_INT:
         case BSON_TIMESTAMP:
         case BSON_LONG:
            assert(false); // not implemented yet or not simple type
            break;
      }
   }
   mrjsonEndArray(context); 
}


