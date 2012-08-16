#ifndef __MRBSON_H__
#define __MRBSON_H__

/*
 * mrbson --
 *
 * this is a bson -> json helper library. some parts rely on the mrjson and mongo c driver libraries.
 *
 */ 

#include <sys/time.h>
#include <string>

#include "lib/mongo-c-driver/src/mongo.h"
#include "lib/mrjson/mrjson.h"

using namespace std;

string mrbsonOidString(bson_oid_t *oid);

string oidConciseTimeAgoInWordsString(bson_oid_t *oid);

bool mrbsonFindOidString(bson *data,
                         const string &bsonField,
                         string &outputOidString);

bool mrbsonFindOid(bson *data,
                   const string &bsonField,
                   bson_oid_t *outputOid);

void mrbsonOidConciseTimeAgoAttribute(mrjsonContext context,
                                      bson *data, 
                                      const string &bsonField, 
                                      const string& outputName);

void mrbsonOidAttribute(mrjsonContext context,
                        bson *data, 
                        const string &bsonField, 
                        const string& outputName);

void mrbsonIntAttribute(mrjsonContext context,
                        bson *data, 
                        const string &bsonField, 
                        const string& outputName);

void mrbsonBoolAttribute(mrjsonContext context,
                         bson *data, 
                         const string &bsonField, 
                         const string& outputName);

void mrbsonDoubleAttribute(mrjsonContext context,
                           bson *data,
                           const string &bsonField,
                           const string& outputName);

void mrbsonStringAttribute(mrjsonContext context,
                           bson *data,
                           const string &bsonField,
                           const string& outputName);

void mrbsonSimpleArrayAttribute(mrjsonContext context,
                                bson *data,
                                const string &bsonField,
                                const string& outputName);

#endif  // __MRBSON_H__
