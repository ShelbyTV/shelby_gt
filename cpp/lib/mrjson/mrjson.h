#ifndef __MRJSON_H__
#define __MRJSON_H__

/*
 * mrjson --
 *
 * this is a json generation library.
 *
 * it provides methods to print json objects, vectors, and elements of objects.
 *
 * it makes use of a context struct to keep track of object depth level, number
 * of objects printed at each level thus far, etc.
 *
 * this library is capable of both "pretty" and "minified" output.
 *
 */ 

#include <assert.h>

using namespace std;

/* DATA STRUCTURES AND CONSTANTS */

#define MRJSON_MAX_LEVELS 20

typedef enum mrjsonResponseStatus
{
   UNINITIALIZED = 0,
   OPEN,
   FINISHED
} mrjResponseStatus;

typedef struct mrjsonLevel
{
   bool objectOpen;
   bool arrayOpen;
   bool anythingPrinted;

} mrjsonLevel;

typedef struct mrjsonContext
{
   mrjsonResponseStatus status;
   unsigned int currentLevel;
   bool pretty;

   mrjsonLevel levels[MRJSON_MAX_LEVELS]; 

} mrjsonContext;

/* PRIVATE MACROS */

// these assume that a variable 'context' exists and that COUT
// and ENDL will be call in pairs

#define MRJSON_COUT {{                                                \
   if (context->pretty) {                                             \
      for (unsigned int i = 0; i < context->currentLevel; i++) {      \
         cout << "  ";                                                \
      }                                                               \
   }                                                                  \
   if (context->levels[context->currentLevel].anythingPrinted) {      \
      if (context->pretty) {                                          \
         cout << " ";                                                 \
      }                                                               \
      cout << ",";                                                    \
   } else if (context->pretty && OPEN == context->status) {           \
      cout << "  ";                                                   \
   }                                                                  \
   cout 

#define MRJSON_ENDL "";}                                              \
   if (context->pretty) {                                             \
      cout << endl;                                                   \
   }                                                                  \
}

/* PUBLIC FUNCTIONS */

void mrjsonInitContext(mrjsonContext *context)
{
   assert(context);

   memset(context, 0, sizeof(mrjsonContext));
}

void mrjsonSetPretty(mrjsonContext *context, bool pretty)
{
   assert(context);
   assert(UNINITIALIZED == context->status);

   context->pretty = pretty;
}

void mrjsonStartResponse(mrjsonContext *context)
{
   assert(context);
   assert(UNINITIALIZED == context->status);
   assert(0 == context->currentLevel);

   MRJSON_COUT << "{" << MRJSON_ENDL;

   context->status = OPEN;
   context->levels[0].objectOpen = true;
}

void mrjsonEndResponse(mrjsonContext *context)
{
   assert(context);
   assert(OPEN == context->status);
   assert(0 == context->currentLevel);
   assert(context->levels[0].objectOpen);
   assert(!context->levels[0].arrayOpen);
 
   context->status = FINISHED; 
   // zero-out currentLevel here so that we don't get a comma printed
   memset(&context->levels[context->currentLevel], 0, sizeof(mrjsonLevel));

   MRJSON_COUT << "}" << MRJSON_ENDL;
}

void mrjsonIntAttribute(mrjsonContext *context, const string& name, int value)
{
   assert(context);
   assert(OPEN == context->status);
   assert(context->levels[context->currentLevel].objectOpen ||
          context->levels[context->currentLevel].arrayOpen);
   assert(!(context->levels[context->currentLevel].objectOpen &&
            context->levels[context->currentLevel].arrayOpen));

   MRJSON_COUT << "\"" << name << "\":" << value << MRJSON_ENDL;
   context->levels[context->currentLevel].anythingPrinted = true;
}

void mrjsonBoolAttribute(mrjsonContext *context, const string& name, bool value)
{
   assert(context);
   assert(OPEN == context->status);
   assert(context->levels[context->currentLevel].objectOpen ||
          context->levels[context->currentLevel].arrayOpen);
   assert(!(context->levels[context->currentLevel].objectOpen &&
            context->levels[context->currentLevel].arrayOpen));

   MRJSON_COUT << "\"" << name << "\":" << (value ? "true" : "false") << MRJSON_ENDL;
   context->levels[context->currentLevel].anythingPrinted = true;
}

void mrjsonDoubleAttribute(mrjsonContext *context, const string& name, double value)
{
   assert(context);
   assert(OPEN == context->status);
   assert(context->levels[context->currentLevel].objectOpen ||
          context->levels[context->currentLevel].arrayOpen);
   assert(!(context->levels[context->currentLevel].objectOpen &&
            context->levels[context->currentLevel].arrayOpen));

   MRJSON_COUT << "\"" << name << "\":" << value << MRJSON_ENDL;
   context->levels[context->currentLevel].anythingPrinted = true;
}

void mrjsonStringAttribute(mrjsonContext *context, const string& name, const string& value)
{
   assert(context);
   assert(OPEN == context->status);
   assert(context->levels[context->currentLevel].objectOpen ||
          context->levels[context->currentLevel].arrayOpen);
   assert(!(context->levels[context->currentLevel].objectOpen &&
            context->levels[context->currentLevel].arrayOpen));

   MRJSON_COUT << "\"" << name << "\":" << "\"" << value << "\"" << MRJSON_ENDL;
   context->levels[context->currentLevel].anythingPrinted = true;
}

void mrjsonNullAttribute(mrjsonContext *context, const string& name)
{
   assert(context);
   assert(OPEN == context->status);
   assert(context->levels[context->currentLevel].objectOpen ||
          context->levels[context->currentLevel].arrayOpen);
   assert(!(context->levels[context->currentLevel].objectOpen &&
            context->levels[context->currentLevel].arrayOpen));

   MRJSON_COUT << "\"" << name << "\":" << "null" << MRJSON_ENDL;
   context->levels[context->currentLevel].anythingPrinted = true;
}

void mrjsonEmptyArrayAttribute(mrjsonContext *context, const string& name)
{
   assert(context);
   assert(OPEN == context->status);
   assert(context->levels[context->currentLevel].objectOpen ||
          context->levels[context->currentLevel].arrayOpen);
   assert(!(context->levels[context->currentLevel].objectOpen &&
            context->levels[context->currentLevel].arrayOpen));

   MRJSON_COUT << "\"" << name << "\":" << "[]" << MRJSON_ENDL;
   context->levels[context->currentLevel].anythingPrinted = true;
}

void mrjsonStartArray(mrjsonContext *context, const string& name)
{
   assert(context);
   assert(OPEN == context->status);
   assert(context->levels[context->currentLevel].objectOpen ||
          context->levels[context->currentLevel].arrayOpen);
   assert(!(context->levels[context->currentLevel].objectOpen &&
          context->levels[context->currentLevel].arrayOpen));
   assert(context->currentLevel + 1 < MRJSON_MAX_LEVELS);

   if (name != "") {
      MRJSON_COUT << "\"" << name << "\":" << "[" << MRJSON_ENDL;
   } else {
      MRJSON_COUT << "[" << MRJSON_ENDL;
   }
   context->levels[context->currentLevel].anythingPrinted = true;

   context->currentLevel++;
   memset(&context->levels[context->currentLevel], 0, sizeof(mrjsonLevel));
   context->levels[context->currentLevel].arrayOpen = true;
}

void mrjsonEndArray(mrjsonContext *context)
{
   assert(context);
   assert(OPEN == context->status);
   assert(context->levels[context->currentLevel].arrayOpen);
   assert(!context->levels[context->currentLevel].objectOpen);
   assert(context->currentLevel > 0); // level 0 is always the response, not an array

   // zero-out currentLevel here so that we don't get a comma printed
   memset(&context->levels[context->currentLevel], 0, sizeof(mrjsonLevel));
   MRJSON_COUT << "]" << MRJSON_ENDL;

   context->currentLevel--;
   assert(context->levels[context->currentLevel].anythingPrinted); // should be set by StartArray
}

void mrjsonStartArray(mrjsonContext *context) 
{
   mrjsonStartArray(context, "");
}

void mrjsonStartObject(mrjsonContext *context, const string& name)
{
   assert(context);
   assert(OPEN == context->status);
   assert(context->levels[context->currentLevel].objectOpen ||
          context->levels[context->currentLevel].arrayOpen);
   assert(!(context->levels[context->currentLevel].objectOpen &&
          context->levels[context->currentLevel].arrayOpen));
   assert(context->currentLevel + 1 < MRJSON_MAX_LEVELS);

   if (name != "") {
      MRJSON_COUT << "\"" << name << "\":" << "{" << MRJSON_ENDL;
   } else {
      MRJSON_COUT << "{" << MRJSON_ENDL;
   }
   context->levels[context->currentLevel].anythingPrinted = true;

   context->currentLevel++;
   memset(&context->levels[context->currentLevel], 0, sizeof(mrjsonLevel));
   context->levels[context->currentLevel].objectOpen = true;
}

void mrjsonStartObject(mrjsonContext *context) 
{
   mrjsonStartObject(context, "");
}

void mrjsonEndObject(mrjsonContext *context)
{
   assert(context);
   assert(OPEN == context->status);
   assert(context->levels[context->currentLevel].objectOpen);
   assert(!context->levels[context->currentLevel].arrayOpen);
   assert(context->currentLevel > 0); // level 0 is always the response, not an object

   // zero-out currentLevel here so that we don't get a comma printed
   memset(&context->levels[context->currentLevel], 0, sizeof(mrjsonLevel));

   MRJSON_COUT << "}" << MRJSON_ENDL;

   context->currentLevel--;
   assert(context->levels[context->currentLevel].anythingPrinted); // should be set by StartObject
}

#endif  // __MRJSON_H__
