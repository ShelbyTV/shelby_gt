#ifndef __SOB_H__
#define __SOB_H__

/*
 * sob.h -- Shelby Objects
 */

#include <string>
#include <vector>

#include "sobProperties.h"

/*
 * Right now these are only the top level types used for DB
 * querying.
 *
 * Sub-types like MESSAGE are aviailable in sobField, etc. but
 * not here since they're currently only accessible via a 
 * CONVERSATION.
 */
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

#define SOB_FIELD(a,b,c,d,e) SOB_##a##_##c,
typedef enum sobField
{
   ALL_PROPERTIES(SOB_FIELD) 
} sobField;

typedef struct sobContextStruct *sobContext;

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

void sobGetBsonVector(sobContext context,
                      sobType type,
                      std::vector<bson *> &result);

void sobGetOidVectorFromObjectField(sobContext context,
                                    sobType type,
                                    sobField field,
                                    std::vector<bson_oid_t> &result);

void sobLoadAllById(sobContext context,
                    sobType type,
                    const std::vector<bson_oid_t> &oids);

#endif // __SOB_H__
