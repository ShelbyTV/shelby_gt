#ifndef __SOB_H__
#define __SOB_H__

/*
 * sob.h -- Shelby Objects
 */

#include "sobProperties.h"
#include "lib/cvector/cvector.h"

#ifdef __cplusplus
extern "C" {
#endif

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

sobEnvironment sobEnvironmentFromString(char *env);

sobContext sobAllocContext(sobEnvironment env);
void sobFreeContext(sobContext context);
int sobConnect(sobContext context);

bson_oid_t sobGetUniqueOidByStringField(sobContext context,
                                        sobType type, 
                                        sobField field,
                                        const char *value);

void sobLoadAllByOidField(sobContext context, 
                          sobType type,
                          sobField field,
                          bson_oid_t oid,
                          unsigned int limit,
                          unsigned int skip,
                          int order);

int sobGetBsonByOid(sobContext context,
                    sobType type,
                    bson_oid_t oid,
                    bson **result);

/*
 * cvector should be initialized with sizeof(bson *)
 */
void sobGetBsonVector(sobContext context,
                      sobType type,
                      cvector result);

/*
 * cvector should be initialized with sizeof(bson_oid_t)
 */
void sobGetOidVectorFromObjectField(sobContext context,
                                    sobType type,
                                    sobField field,
                                    cvector result);

void sobLoadAllById(sobContext context,
                    sobType type,
                    cvector oids);

void sobPrintAttributes(mrjsonContext context,
                        bson *object,
                        sobField *fieldArray,
                        unsigned int numFields);

void sobPrintAttributeWithKeyOverride(mrjsonContext context,
                                      bson *object,
                                      sobField field,
                                      const char *key);

void sobPrintOidConciseTimeAgoAttribute(mrjsonContext context,
                                        bson *object,
                                        sobField oidField,
                                        const char *key);

typedef void (*sobSubobjectPrintCallback)(sobContext, mrjsonContext, bson *);

void sobPrintSubobjectByOid(sobContext sob,
                            mrjsonContext context,
                            bson *object,
                            sobField subobjectOidField,
                            sobType subobjectType,
                            const char *key,
                            sobSubobjectPrintCallback);

void sobPrintSubobjectArray(sobContext sob,
                            mrjsonContext context,
                            bson *object,
                            sobField subobjectOidField,
                            sobSubobjectPrintCallback);

#ifdef __cplusplus
}
#endif

#endif // __SOB_H__
