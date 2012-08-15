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

#include <string>

typedef struct mrjsonContextStruct *mrjsonContext;

mrjsonContext mrjsonAllocContext(bool pretty);
void mrjsonPrintContext(mrjsonContext context);
void mrjsonFreeContext(mrjsonContext context);

void mrjsonStartResponse(mrjsonContext context);
void mrjsonEndResponse(mrjsonContext context);

// object attributes
void mrjsonIntAttribute(mrjsonContext context, const std::string& name, int value);
void mrjsonBoolAttribute(mrjsonContext context, const std::string& name, bool value);
void mrjsonDoubleAttribute(mrjsonContext context, const std::string& name, double value);
void mrjsonStringAttribute(mrjsonContext context, const std::string& name, const std::string& value);
void mrjsonNullAttribute(mrjsonContext context, const std::string& name);
void mrjsonEmptyArrayAttribute(mrjsonContext context, const std::string& name);

// array entries
void mrjsonStringArrayEntry(mrjsonContext context, const std::string &value);

void mrjsonStartArray(mrjsonContext context, const std::string& name);
void mrjsonStartArray(mrjsonContext context);
void mrjsonEndArray(mrjsonContext context);

void mrjsonStartObject(mrjsonContext context, const std::string& name);
void mrjsonStartObject(mrjsonContext context);
void mrjsonEndObject(mrjsonContext context);

#endif  // __MRJSON_H__
