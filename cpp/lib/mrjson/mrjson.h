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

#ifdef __cplusplus
extern "C" {
#endif

typedef struct mrjsonContextStruct *mrjsonContext;

mrjsonContext mrjsonAllocContext(int pretty);
void mrjsonPrintContext(mrjsonContext context);
void mrjsonFreeContext(mrjsonContext context);

void mrjsonStartResponse(mrjsonContext context);
void mrjsonEndResponse(mrjsonContext context);

// object attributes
void mrjsonIntAttribute(mrjsonContext context, const char *name, int value);
void mrjsonLongAttribute(mrjsonContext context, const char *name, long int value);
void mrjsonBoolAttribute(mrjsonContext context, const char *name, int value);
void mrjsonDoubleAttribute(mrjsonContext context, const char *name, double value);
void mrjsonStringAttribute(mrjsonContext context, const char *name, const char *value);
void mrjsonNullAttribute(mrjsonContext context, const char *name);
void mrjsonEmptyArrayAttribute(mrjsonContext context, const char *name);

// array entries
void mrjsonStringArrayEntry(mrjsonContext context, const char *value);

void mrjsonStartArray(mrjsonContext context, const char *name);
void mrjsonStartNamelessArray(mrjsonContext context);
void mrjsonEndArray(mrjsonContext context);

void mrjsonStartObject(mrjsonContext context, const char *name);
void mrjsonStartNamelessObject(mrjsonContext context);
void mrjsonEndObject(mrjsonContext context);

#ifdef __cplusplus
}
#endif

#endif  // __MRJSON_H__
