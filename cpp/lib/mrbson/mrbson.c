#include <assert.h>
#include <sys/time.h>

#include "lib/mongo-c-driver/src/mongo.h"
#include "lib/mrjson/mrjson.h"
#include "lib/mrbson/mrbson.h"

#define FALSE 0
#define TRUE 1

void oidConciseTimeAgoInWordsString(bson_oid_t *oid, char *buffer)
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

    if (minutes <= 1) {
       snprintf(buffer, 100, "just now");
    } else if (minutes <= 59) {
       snprintf(buffer, 100, "%dm ago", (int)minutes);
    } else if (minutes <= 720) {
       snprintf(buffer, 100, "%dh ago", (int)minutes / 60);
    } else {
       struct tm *date = gmtime(&oidTime);
       strftime(buffer, 100, "%b %-d", date);
    }
}

int mrbsonFindOid(bson *data,
                  const char *bsonField,
                  bson_oid_t *outputOid)
{
   bson_iterator iterator;
   bson_type type;
 
   type = bson_find(&iterator, data, bsonField);
   if (type != BSON_OID) {
      return FALSE;
   }

   // possibly we should just return the reference instead of the copy?
   *outputOid = *bson_iterator_oid(&iterator);
   return TRUE;
}

void mrbsonOidConciseTimeAgoAttribute(mrjsonContext context,
                                      bson *data, 
                                      const char *bsonField, 
                                      const char *outputName)
{
   bson_iterator iterator;
   bson_type type;
 
   type = bson_find(&iterator, data, bsonField);
   if (type == BSON_OID) {   
     char buffer[100];
     oidConciseTimeAgoInWordsString(bson_iterator_oid(&iterator), buffer);
     mrjsonStringAttribute(context, outputName, buffer);
   } else {
     mrjsonStringAttribute(context, outputName, ""); 
   }
}


void mrbsonOidAttribute(mrjsonContext context,
                        bson *data, 
                        const char *bsonField, 
                        const char *outputName)
{
   bson_iterator iterator;
   bson_type type;

   type = bson_find(&iterator, data, bsonField);
   if (type == BSON_OID) {
     char buffer[100];
     bson_oid_to_string(bson_iterator_oid(&iterator), buffer);
     mrjsonStringAttribute(context, outputName, buffer);
   } else {
     mrjsonNullAttribute(context, outputName); 
   }
}

void mrbsonIntAttribute(mrjsonContext context,
                        bson *data, 
                        const char *bsonField, 
                        const char *outputName)
{
   bson_iterator iterator;
   bson_type type;
 
   type = bson_find(&iterator, data, bsonField);
   if (type == BSON_INT) {
     mrjsonIntAttribute(context, outputName, bson_iterator_int(&iterator));
   } else {
     mrjsonIntAttribute(context, outputName, 0); 
   }
}

void mrbsonBoolAttribute(mrjsonContext context,
                         bson *data,
                         const char *bsonField, 
                         const char *outputName)
{
   bson_iterator iterator;
   bson_type type;
 
   type = bson_find(&iterator, data, bsonField);
   if (type == BSON_BOOL) {
     mrjsonBoolAttribute(context, outputName, bson_iterator_bool(&iterator));
   } else {
     mrjsonNullAttribute(context, outputName); 
   }
}

void mrbsonStringAsBoolAttribute(mrjsonContext context,
                                 bson *data,
                                 const char *bsonField,
                                 const char *outputName)
{
   bson_iterator iterator;
   bson_type type;
   int stringIsNotEmpty;

   type = bson_find(&iterator, data, bsonField);
   if (type == BSON_STRING) {
     stringIsNotEmpty = strlen(bson_iterator_string(&iterator)) > 0;
     mrjsonBoolAttribute(context, outputName, stringIsNotEmpty);
   } else {
     mrjsonBoolAttribute(context, outputName, FALSE);
   }
}

void mrbsonDoubleAttribute(mrjsonContext context,
                           bson *data,
                           const char *bsonField,
                           const char *outputName)
{
   bson_iterator iterator;
   bson_type type;
 
   type = bson_find(&iterator, data, bsonField);
   if (type == BSON_DOUBLE) {
     mrjsonDoubleAttribute(context, outputName, bson_iterator_double(&iterator));
   } else {
     mrjsonDoubleAttribute(context, outputName, 0); 
   }
}

void mrbsonStringAttribute(mrjsonContext context,
                           bson *data,
                           const char *bsonField,
                           const char *outputName)
{
   bson_iterator iterator;
   bson_type type;
 
   type = bson_find(&iterator, data, bsonField);
   if (type == BSON_STRING) {
     mrjsonStringAttribute(context, outputName, bson_iterator_string(&iterator));
   } else {
     mrjsonNullAttribute(context, outputName); 
   }
}

void mrbsonDateAttribute(mrjsonContext context,
                         bson *data,
                         const char *bsonField,
                         const char *outputName)
{
  bson_iterator iterator;
  bson_type type;

  type = bson_find(&iterator, data, bsonField);
  if (type == BSON_DATE) {
    // bson_iterator_date(&iterator) returns a bson_date_t 
    // which is typedef int64_t, a long int
    mrjsonLongAttribute(context, outputName, bson_iterator_date(&iterator));
  } else {
    mrjsonNullAttribute(context, outputName); 
  }
}

void mrbsonSimpleArrayAttribute(mrjsonContext context,
                                bson *data,
                                const char *bsonField,
                                const char *outputName)
{
   bson array;
   bson_iterator iterator;
   bson_type type;

   type = bson_find(&iterator, data, bsonField);
   if(type == BSON_ARRAY){
     bson_iterator_subobject(&iterator, &array);
     bson_iterator_from_buffer(&iterator, array.data);

     mrjsonStartArray(context, outputName);
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
              assert(FALSE); // not implemented yet or not simple type
              break;
        }
     }
     mrjsonEndArray(context); 
   } else {
     mrjsonNullAttribute(context, outputName); 
     // if we needed an empty array instead, could do this:
     // mrjsonStartArray(context, outputName);
     // mrjsonEndArray(context);
   }
}


