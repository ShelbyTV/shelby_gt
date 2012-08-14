#ifndef __SOB_H__
#define __SOB_H__

/*
 * sob.h -- Shelby Objects
 */

#include <string>
#include <vector>

typedef enum sobType
{
   SOB_USER = 0,
   SOB_FRAME,
   SOB_ROLL,
   SOB_CONVERSATION,
   SOB_VIDEO,
   SOB_DASHBOARD_ENTRY,

   // one final entry to make it easy to calculate number for arrays
   SOB_NUMTYPES
} sobType;

typedef enum sobEnvironment
{
   SOB_DEVELOPMENT = 0,
   SOB_TEST,
   SOB_PRODUCTION,

   // one final entry to make it easy to calculate number for arrays
   SOB_NUMENVIRONMENTS
} sobEnvironment;

typedef struct sobContextStruct *sobContext;
typedef std::string sobField; // TODO

sobContext sobAllocContext(sobEnvironment env);
void sobFreeContext(sobContext context);
bool sobConnect(sobContext context);

bson_oid_t sobGetUniqueOidByStringField(sobContext context,
                                        sobType type, 
                                        sobField field,
                                        const std::string &value);

void sobLoadAllByOidField(sobContext context, 
                          sobType type,
                          sobField field,
                          bson_oid_t oid,
                          unsigned int limit,
                          unsigned int skip,
                          int order);

bool sobGetBsonByOid(sobContext context,
                     sobType type,
                     bson_oid_t oid,
                     bson **result);

bool sobGetBsonVector(sobContext context,
                      sobType type,
                      std::vector<bson *> &result);

bool sobGetOidVectorFromObjectField(sobContext context,
                                    sobType type,
                                    sobField field,
                                    std::vector<bson_oid_t> &result);

void sobLoadAllById(sobContext context,
                    sobType type,
                    const std::vector<bson_oid_t> &oids);

#endif // __SOB_H__
