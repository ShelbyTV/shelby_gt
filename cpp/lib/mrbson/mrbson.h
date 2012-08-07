#ifndef __MRBSON_H__
#define __MRBSON_H__

/*
 * mrbson --
 *
 * this is a bson -> json helper library. some parts rely on the mrjson and mongo c driver libraries.
 *
 */ 

#include <assert.h>

#include "lib/mongo-c-driver/src/mongo.h"
#include "lib/mrjson/mrjson.h"

using namespace std;

string mrbsonOidString(bson_oid_t *oid)
{
   char buffer[100]; // an oid is 24 hex chars + null byte, let's go big to ensure compatibility
  
   bson_oid_to_string(oid, buffer);
   return string(buffer); 
}

bool mrbsonFindOid(bson *data,
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

void mrbsonOidAttribute(mrjsonContext *context,
                        bson *data, 
                        const string &bsonField, 
                        const string& outputName)
{
   bson_iterator iterator;
   bson_type type;
 
   type = bson_find(&iterator, data, bsonField.c_str());
   if (type == BSON_OID) {
     mrjsonStringAttribute(context, outputName, mrbsonOidString(bson_iterator_oid(&iterator)));
   } else {
     mrjsonNullAttribute(context, outputName); 
   }
}

void mrbsonIntAttribute(mrjsonContext *context,
                        bson *data, 
                        const string &bsonField, 
                        const string& outputName)
{
   bson_iterator iterator;
   bson_type type;
 
   type = bson_find(&iterator, data, bsonField.c_str());
   if (type == BSON_INT) {
     mrjsonIntAttribute(context, outputName, bson_iterator_int(&iterator));
   } else {
     mrjsonIntAttribute(context, outputName, 0); 
   }
}

void mrbsonBoolAttribute(mrjsonContext *context,
                         bson *data, 
                         const string &bsonField, 
                         const string& outputName)
{
   bson_iterator iterator;
   bson_type type;
 
   type = bson_find(&iterator, data, bsonField.c_str());
   if (type == BSON_BOOL) {
     mrjsonBoolAttribute(context, outputName, bson_iterator_bool(&iterator));
   } else {
     mrjsonNullAttribute(context, outputName); 
   }
}

void mrbsonDoubleAttribute(mrjsonContext *context,
                           bson *data,
                           const string &bsonField,
                           const string& outputName)
{
   bson_iterator iterator;
   bson_type type;
 
   type = bson_find(&iterator, data, bsonField.c_str());
   if (type == BSON_DOUBLE) {
     mrjsonDoubleAttribute(context, outputName, bson_iterator_double(&iterator));
   } else {
     mrjsonDoubleAttribute(context, outputName, 0); 
   }
}

void mrbsonStringAttribute(mrjsonContext *context,
                           bson *data,
                           const string &bsonField,
                           const string& outputName)
{
   bson_iterator iterator;
   bson_type type;
 
   type = bson_find(&iterator, data, bsonField.c_str());
   if (type == BSON_STRING) {
     mrjsonStringAttribute(context, outputName, bson_iterator_string(&iterator));
   } else {
     mrjsonNullAttribute(context, outputName); 
   }
}

#endif  // __MRBSON_H__
