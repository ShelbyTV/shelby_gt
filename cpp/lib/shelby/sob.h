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
   SOB_CREATOR,
   SOB_ORIGINATOR,
   SOB_ACTOR,
   SOB_FRAME,
   SOB_ANCESTOR_FRAME,
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
   SOB_STAGING,
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
sobEnvironment sobGetEnvironment(sobContext context);

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
                          const char *sinceIdString);

void sobLoadAllByOidFieldSpecifyFields(sobContext context,
                                       sobType type,
                                       sobField field,
                                       bson_oid_t oid,
                                       unsigned int limit,
                                       unsigned int skip,
                                       const char *sinceIdString,
                                       sobField *fieldArray,
                                       unsigned int numFields);

int sobGetBsonByOid(sobContext context,
                    sobType type,
                    bson_oid_t oid,
                    bson **result);

int sobGetBsonByOidField(sobContext context,
                         sobType typeToGet,
                         bson *object,
                         sobField objectOidField,
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

void sobGetOidVectorFromObjectArrayField(sobContext context,
                                         sobType type,
                                         sobField arrayField,
                                         sobField subObjectOidField,
                                         cvector result);

void sobGetOidVectorFromOidArrayField(sobContext context,
                                      sobType type,
                                      sobField arrayField,
                                      cvector result);

void sobGetLastOidVectorFromOidArrayField(sobContext context,
                                          sobType type,
                                          sobField arrayField,
                                          cvector result);

void sobLoadAllById(sobContext context,
                    sobType type,
                    cvector oids);

void sobLoadAllByIdSpecifyFields(sobContext context,
                                 sobType type,
                                 sobField *fieldArray,
                                 unsigned int numFields,
                                 cvector oids);

void sobPrintAttributes(mrjsonContext context,
                        bson *object,
                        sobField *fieldArray,
                        unsigned int numFields);

// If the field exists and is a non-empty string, prints true, else false
void sobPrintStringToBoolAttributeWithKeyOverride(mrjsonContext context,
                                                  bson *object,
                                                  sobField field,
                                                  const char *key);

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

void sobPrintSubobjectArrayWithKey(sobContext sob,
                                   mrjsonContext context,
                                   bson *object,
                                   sobField subobjectOidField,
                                   const char *key,
                                   sobSubobjectPrintCallback);

void sobPrintArrayAttributeCountWithKey(mrjsonContext context,
                                        bson *object,
                                        sobField objectArrayField,
                                        const char *key);

void sobPrintFieldIfBoolField(mrjsonContext context,
                              bson *object,
                              sobField fieldToPrint,
                              sobField fieldToCheck);

int sobBsonOidFieldEqual(sobContext context,
                         sobType objectType,
                         sobField objectOidField,
                         bson_oid_t objectOid,
                         bson_oid_t oidEqual);

int sobBsonBoolField(sobContext context,
                     sobType objectType,
                     sobField fieldToCheck,
                     bson_oid_t objectOid);

int sobBsonIntField(sobContext context,
                    sobType objectType,
                    sobField fieldToCheck,
                    bson_oid_t objectOid,
                    int *result);

int sobBsonIntFieldFromObject(sobContext context,
                              sobType objectType,
                              sobField fieldToCheck,
                              bson *object,
                              int *result);

int sobBsonOidField(sobType objectType,
                    sobField fieldToCheck,
                    bson *object,
                    bson_oid_t *output);

int sobBsonOidArrayFieldLast(sobType objectType,
                             sobField fieldToCheck,
                             bson *object,
                             bson_oid_t *output);

int sobBsonObjectArrayFieldFirst(sobType objectType,
                                 sobField fieldToCheck,
                                 bson *object,
                                 bson *output);

int sobOidArrayFieldContainsOid(sobContext context,
                                sobField arrayField,
                                sobField fieldToCheck,
                                bson *object,
                                bson_oid_t oidToCheck);

int sobBsonOidEqual(bson_oid_t oid1, bson_oid_t oid2);

int sobGetBsonForArrayObjectWithOidField(sobContext sob,
                                         sobType objectType,
                                         bson_oid_t objectOid,
                                         sobField objectField,
                                         sobField arrayObjectField,
                                         bson_oid_t oidToCheck,
                                         bson *output);

unsigned int sobGetOidGenerationTimeSinceEpoch(bson *object, bson_timestamp_t *ts);

void sobLog(const char *format, ...);

#ifdef __cplusplus
}
#endif

#endif // __SOB_H__
