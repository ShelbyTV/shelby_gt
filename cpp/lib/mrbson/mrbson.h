#ifndef __MRBSON_H__
#define __MRBSON_H__

/*
 * mrbson --
 *
 * this is a bson -> json helper library. some parts rely on the mrjson and mongo c driver libraries.
 *
 */ 

#include "lib/mongo-c-driver/src/mongo.h"
#include "lib/mrjson/mrjson.h"

#ifdef __cplusplus
extern "C" {
#endif

int mrbsonFindOid(bson *data,
                  const char *bsonField,
                  bson_oid_t *outputOid);

void mrbsonOidConciseTimeAgoAttribute(mrjsonContext context,
                                      bson *data, 
                                      const char *bsonField, 
                                      const char *outputName);

void mrbsonOidAttribute(mrjsonContext context,
                        bson *data, 
                        const char *bsonField, 
                        const char *outputName);

void mrbsonIntAttribute(mrjsonContext context,
                        bson *data, 
                        const char *bsonField, 
                        const char *outputName);

void mrbsonBoolAttribute(mrjsonContext context,
                         bson *data, 
                         const char *bsonField, 
                         const char *outputName);

void mrbsonDoubleAttribute(mrjsonContext context,
                           bson *data,
                           const char *bsonField,
                           const char *outputName);

void mrbsonStringAttribute(mrjsonContext context,
                           bson *data,
                           const char *bsonField,
                           const char *outputName);

void mrbsonSimpleArrayAttribute(mrjsonContext context,
                                bson *data,
                                const char *bsonField,
                                const char *outputName);

#ifdef __cplusplus
}
#endif

#endif  // __MRBSON_H__
