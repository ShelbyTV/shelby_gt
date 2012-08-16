#include <iostream>

#include <assert.h>
#include <string.h>

#include "mrjson.h"
#include "yajl/src/api/yajl_gen.h"

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

} mrjsonLevel;

struct mrjsonContextStruct
{
   mrjsonResponseStatus status;
   unsigned int currentLevel;

   mrjsonLevel levels[MRJSON_MAX_LEVELS];

   yajl_gen yajl;
};

/* PUBLIC FUNCTIONS */

mrjsonContext mrjsonAllocContext(bool pretty)
{
   mrjsonContext toReturn = (struct mrjsonContextStruct *)malloc(sizeof(struct mrjsonContextStruct));
   memset(toReturn, 0, sizeof(struct mrjsonContextStruct));

   toReturn->yajl = yajl_gen_alloc(NULL);
   if (pretty) {
      yajl_gen_config(toReturn->yajl, yajl_gen_beautify);
   }

   return toReturn;
}

void mrjsonPrintContext(mrjsonContext context)
{
   const unsigned char *yajlBufferPtr;
   size_t yajlBufferLen;

   // TODO: check return value
   yajl_gen_get_buf(context->yajl,
                    &yajlBufferPtr,
                    &yajlBufferLen);

   printf("%s", yajlBufferPtr);

   yajl_gen_free(context->yajl);
}

void mrjsonFreeContext(mrjsonContext context)
{
   free(context);
}

void mrjsonStartResponse(mrjsonContext context)
{
   assert(context);
   assert(UNINITIALIZED == context->status);
   assert(0 == context->currentLevel);

   yajl_gen_map_open(context->yajl);

   context->status = OPEN;
   context->levels[0].objectOpen = true;
}

void mrjsonEndResponse(mrjsonContext context)
{
   assert(context);
   assert(OPEN == context->status);
   assert(0 == context->currentLevel);
   assert(context->levels[0].objectOpen);
   assert(!context->levels[0].arrayOpen);
 
   context->status = FINISHED; 
   memset(&context->levels[context->currentLevel], 0, sizeof(mrjsonLevel));

   yajl_gen_map_close(context->yajl);
}

void mrjsonIntAttribute(mrjsonContext context, const char *name, int value)
{
   assert(context);
   assert(OPEN == context->status);
   assert(context->levels[context->currentLevel].objectOpen ||
          context->levels[context->currentLevel].arrayOpen);
   assert(!(context->levels[context->currentLevel].objectOpen &&
            context->levels[context->currentLevel].arrayOpen));

   yajl_gen_string(context->yajl, (const unsigned char *)name, strlen(name));
   yajl_gen_integer(context->yajl, value);
}

void mrjsonBoolAttribute(mrjsonContext context, const char *name, bool value)
{
   assert(context);
   assert(OPEN == context->status);
   assert(context->levels[context->currentLevel].objectOpen ||
          context->levels[context->currentLevel].arrayOpen);
   assert(!(context->levels[context->currentLevel].objectOpen &&
            context->levels[context->currentLevel].arrayOpen));

   yajl_gen_string(context->yajl, (const unsigned char *)name, strlen(name));
   yajl_gen_bool(context->yajl, value);
}

void mrjsonDoubleAttribute(mrjsonContext context, const char *name, double value)
{
   assert(context);
   assert(OPEN == context->status);
   assert(context->levels[context->currentLevel].objectOpen ||
          context->levels[context->currentLevel].arrayOpen);
   assert(!(context->levels[context->currentLevel].objectOpen &&
            context->levels[context->currentLevel].arrayOpen));

   yajl_gen_string(context->yajl, (const unsigned char *)name, strlen(name));
   yajl_gen_double(context->yajl, value);
}

void mrjsonStringAttribute(mrjsonContext context, const char *name, const char *value)
{
   assert(context);
   assert(OPEN == context->status);
   assert(context->levels[context->currentLevel].objectOpen ||
          context->levels[context->currentLevel].arrayOpen);
   assert(!(context->levels[context->currentLevel].objectOpen &&
            context->levels[context->currentLevel].arrayOpen));

   yajl_gen_string(context->yajl, (const unsigned char *)name, strlen(name));
   yajl_gen_string(context->yajl, (const unsigned char *)value, strlen(value));
}

void mrjsonNullAttribute(mrjsonContext context, const char *name)
{
   assert(context);
   assert(OPEN == context->status);
   assert(context->levels[context->currentLevel].objectOpen ||
          context->levels[context->currentLevel].arrayOpen);
   assert(!(context->levels[context->currentLevel].objectOpen &&
            context->levels[context->currentLevel].arrayOpen));

   yajl_gen_string(context->yajl, (const unsigned char *)name, strlen(name));
   yajl_gen_null(context->yajl);
}

void mrjsonEmptyArrayAttribute(mrjsonContext context, const char *name)
{
   assert(context);
   assert(OPEN == context->status);
   assert(context->levels[context->currentLevel].objectOpen ||
          context->levels[context->currentLevel].arrayOpen);
   assert(!(context->levels[context->currentLevel].objectOpen &&
            context->levels[context->currentLevel].arrayOpen));

   yajl_gen_string(context->yajl, (const unsigned char *)name, strlen(name));
   yajl_gen_array_open(context->yajl);
   yajl_gen_array_close(context->yajl);
}

void mrjsonStringArrayEntry(mrjsonContext context, const char *value) 
{
   assert(context);
   assert(OPEN == context->status);
   assert(context->levels[context->currentLevel].arrayOpen);
   assert(!context->levels[context->currentLevel].objectOpen);
   assert(context->currentLevel > 0); // level 0 is always the response, not an array

   yajl_gen_string(context->yajl, (const unsigned char *)value, strlen(value));
}

void mrjsonStartArray(mrjsonContext context, const char *name)
{
   assert(context);
   assert(OPEN == context->status);
   assert(context->levels[context->currentLevel].objectOpen ||
          context->levels[context->currentLevel].arrayOpen);
   assert(!(context->levels[context->currentLevel].objectOpen &&
          context->levels[context->currentLevel].arrayOpen));
   assert(context->currentLevel + 1 < MRJSON_MAX_LEVELS);

   if (strcmp(name, "") != 0) {
      yajl_gen_string(context->yajl, (const unsigned char *)name, strlen(name));
      yajl_gen_array_open(context->yajl);
   } else {
      yajl_gen_array_open(context->yajl);
   }
   context->currentLevel++;
   memset(&context->levels[context->currentLevel], 0, sizeof(mrjsonLevel));
   context->levels[context->currentLevel].arrayOpen = true;
}

void mrjsonEndArray(mrjsonContext context)
{
   assert(context);
   assert(OPEN == context->status);
   assert(context->levels[context->currentLevel].arrayOpen);
   assert(!context->levels[context->currentLevel].objectOpen);
   assert(context->currentLevel > 0); // level 0 is always the response, not an array

   // zero-out currentLevel here so that we don't get a comma printed
   memset(&context->levels[context->currentLevel], 0, sizeof(mrjsonLevel));
   yajl_gen_array_close(context->yajl);

   context->currentLevel--;
}

void mrjsonStartArray(mrjsonContext context) 
{
   mrjsonStartArray(context, "");
}

void mrjsonStartObject(mrjsonContext context, const char *name)
{
   assert(context);
   assert(OPEN == context->status);
   assert(context->levels[context->currentLevel].objectOpen ||
          context->levels[context->currentLevel].arrayOpen);
   assert(!(context->levels[context->currentLevel].objectOpen &&
          context->levels[context->currentLevel].arrayOpen));
   assert(context->currentLevel + 1 < MRJSON_MAX_LEVELS);

   if (strcmp(name, "") != 0) {
      yajl_gen_string(context->yajl, (const unsigned char *)name, strlen(name));
      yajl_gen_map_open(context->yajl);
   } else {
      yajl_gen_map_open(context->yajl);
   }

   context->currentLevel++;
   memset(&context->levels[context->currentLevel], 0, sizeof(mrjsonLevel));
   context->levels[context->currentLevel].objectOpen = true;
}

void mrjsonStartObject(mrjsonContext context) 
{
   mrjsonStartObject(context, "");
}

void mrjsonEndObject(mrjsonContext context)
{
   assert(context);
   assert(OPEN == context->status);
   assert(context->levels[context->currentLevel].objectOpen);
   assert(!context->levels[context->currentLevel].arrayOpen);
   assert(context->currentLevel > 0); // level 0 is always the response, not an object

   // zero-out currentLevel here so that we don't get a comma printed
   memset(&context->levels[context->currentLevel], 0, sizeof(mrjsonLevel));

   yajl_gen_map_close(context->yajl);

   context->currentLevel--;
}

