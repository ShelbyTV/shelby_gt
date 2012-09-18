#include <assert.h>

#include "lib/mongo-c-driver/src/mongo.h"
#include "lib/mrbson/mrbson.h"
#include "lib/cvector/cvector.h"

#include "sob.h"
#include "sobDatabases.h"
#include "sobProperties.h"

#define FALSE 0
#define TRUE 1

#define ISREPLSET(a,b,c,d,e,f,g,h,i) d,
static int sobIsReplSetConnection[] =
   { ALL_DATABASES(ISREPLSET) };
#undef ISREPLSET

#define REPLSETNAME(a,b,c,d,e,f,g,h,i) #e,
static const char *sobReplSetName[] =
   { ALL_DATABASES(REPLSETNAME) };
#undef REPLSETNAME

#define PRIMARYSERVER(a,b,c,d,e,f,g,h,i) #f,
static const char *sobPrimaryServer[] = 
   { ALL_DATABASES(PRIMARYSERVER) };
#undef PRIMARYSERVER

#define SECONDARYSERVER(a,b,c,d,e,f,g,h,i) #g,
static const char *sobSecondaryServer[] =
   { ALL_DATABASES(SECONDARYSERVER) };
#undef SECONDARYSERVER

#define DBUSER(a,b,c,d,e,f,g,h,i) #h,
static const char *sobDBUser[] =
   { ALL_DATABASES(DBUSER) };
#undef DBUSER

#define DBPASSWORD(a,b,c,d,e,f,g,h,i) #i,
static const char *sobDBPassword[] =
   { ALL_DATABASES(DBPASSWORD) };
#undef DBPASSWORD

#define DBCOLLECTION(a,b,c,d,e,f,g,h,i) #b "." #c,
static const char *sobDBCollection[] =
   { ALL_DATABASES(DBCOLLECTION) };
#undef DBCOLLECTION 

#define DBNAME(a,b,c,d,e,f,g,h,i) #b,
static const char *sobDBName[] =
   { ALL_DATABASES(DBNAME) };
#undef DBNAME

#define FIELD_DB_NAME(a,b,c,d,e) #e,
static const char *sobFieldDBName[] =
   { ALL_PROPERTIES(FIELD_DB_NAME) };
#undef FIELD_DB_NAME

#define FIELD_BSON_TYPE(a,b,c,d,e) BSON_##d,
static bson_type sobFieldBSONType[] =
   { ALL_PROPERTIES(FIELD_BSON_TYPE) };
#undef FIELD_BSON_TYPE

#define FIELD_LONG_NAME(a,b,c,d,e) #b,
static const char *sobFieldLongName[] = 
   { ALL_PROPERTIES(FIELD_LONG_NAME) };
#undef FIELD_LONG_NAME

typedef struct sobContextStruct
{
   sobEnvironment env;

   mongo *allocatedConn[SOB_NUMTYPES];
   mongo *typeToConn[SOB_NUMTYPES];

   cvector objectVector[SOB_NUMTYPES];
} sobContextStruct;

sobEnvironment sobEnvironmentFromString(char *env)
{
   assert(env);

   if (strcmp("development", env) == 0) {
      return SOB_DEVELOPMENT;
   } else if (strcmp("test", env) == 0) {
      return SOB_TEST;
   } else if (strcmp("production", env) == 0) {
      return SOB_PRODUCTION;
   } else {
      printf("Not a known environment type: %s\n", env);
      printf("Acceptable options are: development, test, production\n");
      exit(1);
   }
}

sobContext sobAllocContext(sobEnvironment env)
{
   sobContext toReturn = (sobContextStruct *)malloc(sizeof(sobContextStruct));
   memset(toReturn, 0, sizeof(sobContextStruct));

   toReturn->env = env;

   for (unsigned int i = 0 ; i < SOB_NUMTYPES ; i++) {
      toReturn->objectVector[i] = cvectorAlloc(sizeof(bson *));
   }

   return toReturn;
}

void sobFreeContext(sobContext context)
{
   for (unsigned int i = 0 ; i < SOB_NUMTYPES ; i++) {
      if (context->allocatedConn[i] != NULL) {
         mongo_destroy(context->allocatedConn[i]); 
         free(context->allocatedConn[i]);
      }

      cvectorFree(context->objectVector[i]);
   }

   free(context);
}

sobEnvironment sobGetEnvironment(sobContext context)
{
   assert(context);
   return context->env;
}

unsigned int sobArrayIndex(sobType type, sobEnvironment env)
{
   return ((unsigned int)type * SOB_NUMENVIRONMENTS) + (unsigned int)env;
}

int sobTypesUseSameServer(sobType type1, sobType type2, sobEnvironment env)
{
   unsigned int type1Index = sobArrayIndex(type1, env);
   unsigned int type2Index = sobArrayIndex(type2, env);

   // primary servers always have to match if it's the same type->server mapping
   return (strcmp(sobPrimaryServer[type1Index], sobPrimaryServer[type2Index]) == 0)

          &&

          (
              // replsets need to have the same secondary server also
              (sobIsReplSetConnection[type1Index] &&
               sobIsReplSetConnection[type2Index] &&
               strcmp(sobSecondaryServer[type1Index], sobSecondaryServer[type2Index]) == 0)

                 ||

              // otherwise both server mappings must not be replsets
              (!sobIsReplSetConnection[type1Index] &&
               !sobIsReplSetConnection[type2Index])
          );
}

int sobConnect(sobContext context, sobType type)
{
   if (context->typeToConn[type]) {
     return TRUE;
   }

   for (sobType i = (sobType)0; i < SOB_NUMTYPES; i = (sobType)((unsigned int)i + 1)) {
      // already handled above
      if (i == type) {
         continue;
      }

      // if 2 types need the exact same conn, don't need to allocate another connection
      if (context->typeToConn[i] && sobTypesUseSameServer(i, type, context->env)) {
         context->typeToConn[type] = context->typeToConn[i];
         return TRUE;
      }
   }

   context->allocatedConn[type] = (mongo *)malloc(sizeof(mongo));
   context->typeToConn[type] = context->allocatedConn[type];

   int isReplSet = sobIsReplSetConnection[sobArrayIndex(type, context->env)];
   int status;

   if (isReplSet) {
      mongo_host_port primary;
      mongo_host_port secondary;

      mongo_replset_init(context->allocatedConn[type],
                         sobReplSetName[sobArrayIndex(type, context->env)]);

      mongo_parse_host(sobPrimaryServer[sobArrayIndex(type, context->env)], &primary);
      mongo_parse_host(sobSecondaryServer[sobArrayIndex(type, context->env)] , &secondary);

      mongo_replset_add_seed(context->allocatedConn[type], primary.host, primary.port);
      mongo_replset_add_seed(context->allocatedConn[type], secondary.host, secondary.port);

      status = mongo_replset_connect(context->allocatedConn[type]);

   } else {
      mongo_host_port primary;

      mongo_init(context->allocatedConn[type]);
      mongo_parse_host(sobPrimaryServer[sobArrayIndex(type, context->env)], &primary);

      status = mongo_connect(context->allocatedConn[type], primary.host, primary.port);            
   }

   if (MONGO_OK != status) {
      switch (context->allocatedConn[type]->err) {
         case MONGO_CONN_SUCCESS:    break;
         case MONGO_CONN_NO_SOCKET:  printf("no socket\n"); return FALSE;
         case MONGO_CONN_FAIL:       printf("connection failed\n"); return FALSE;
         case MONGO_CONN_NOT_MASTER: printf("not master\n"); return FALSE;
         default:                    printf("received unknown status\n"); return FALSE;
      }
   }
      
   return TRUE;
}

int sobAuthenticate(sobContext context, sobType type)
{
   if (strcmp(sobDBUser[sobArrayIndex(type, context->env)], "") != 0 &&
       strcmp(sobDBPassword[sobArrayIndex(type, context->env)], "") != 0) {

      int status;

      status = mongo_cmd_authenticate(context->typeToConn[type],
                                      sobDBName[sobArrayIndex(type, context->env)],
                                      sobDBUser[sobArrayIndex(type, context->env)],
                                      sobDBPassword[sobArrayIndex(type, context->env)]);

      if (MONGO_OK != status) {
         switch (context->allocatedConn[type]->err) {
            case MONGO_CONN_SUCCESS:    break;
            case MONGO_CONN_NO_SOCKET:  printf("no socket\n"); return FALSE;
            case MONGO_CONN_FAIL:       printf("connection failed\n"); return FALSE;
            case MONGO_CONN_NOT_MASTER: printf("not master\n"); return FALSE;
            default:                    printf("received unknown status\n"); return FALSE;
         }
      }
   }

   return TRUE;
}

int sobConnectAndAuthenticate(sobContext context, sobType type)
{
   if (!sobConnect(context, type)) {
      return FALSE;
   }
   
   return sobAuthenticate(context, type);
}

bson_oid_t sobGetUniqueOidByStringField(sobContext context,
                                   sobType type,
                                   sobField field,
                                   const char *value)
{
   bson_oid_t result;

   bson query;
   bson_init(&query);
   bson_append_string(&query, sobFieldDBName[field], value);
   bson_finish(&query);
   
   bson fields;
   bson_init(&fields);
   bson_append_int(&fields, "_id", 1);
   bson_finish(&fields);
   
   bson out;
   bson_init(&out);

   // TODO: check return status
   sobConnectAndAuthenticate(context, type);

   if (mongo_find_one(context->typeToConn[type], 
                      sobDBCollection[sobArrayIndex(type, context->env)],
                      &query, 
                      &fields, 
                      &out) == MONGO_OK)
   {
      bson_iterator iterator;
      bson_iterator_init(&iterator, &out);
      result = *bson_iterator_oid(&iterator);
   } 
   
   bson_destroy(&out);
   bson_destroy(&fields);
   bson_destroy(&query);

   return result; 
}

void insertMongoCursorIntoObjectMap(sobContext context,
                                    sobType type,
                                    mongo_cursor *cursor)
{
   while (mongo_cursor_next(cursor) == MONGO_OK) {
      bson_iterator iterator;
      if (bson_find(&iterator, mongo_cursor_bson(cursor), "_id" )) {

         bson *newValue = (bson *)malloc(sizeof(bson));
         bson_copy(newValue, mongo_cursor_bson(cursor));

         cvectorAddElement(context->objectVector[type], &newValue);
      }
   }
}

void sobLoadAllByOidField(sobContext context,
                          sobType type,
                          sobField field,
                          bson_oid_t oid,
			  unsigned int limit,
                          unsigned int skip,
                          const char *sinceIdString)
{
   bson_oid_t sinceId;
   bson query;
   bson_init(&query);
   bson_append_start_object(&query, "$query");
      bson_append_oid(&query, sobFieldDBName[field], &oid);
      if (strcmp("", sinceIdString) != 0) {
         bson_oid_from_string(&sinceId, sinceIdString);
         bson_append_start_object(&query, "_id");
            bson_append_oid(&query, "$lte", &sinceId);
         bson_append_finish_object(&query);
      }
   bson_append_finish_object(&query);
   bson_append_start_object(&query, "$orderby");
      bson_append_int(&query, "_id", -1);
   bson_append_finish_object(&query);
   bson_finish(&query);

   assert(context); 
 
   // TODO: check return status
   sobConnectAndAuthenticate(context, type);
   assert(context->typeToConn[type]);

   mongo_cursor cursor;
   mongo_cursor_init(&cursor, 
                     context->typeToConn[type],
                     sobDBCollection[sobArrayIndex(type, context->env)]);
   mongo_cursor_set_options(&cursor, MONGO_SLAVE_OK);

   mongo_cursor_set_query(&cursor, &query);

   if (limit != 0) {
      mongo_cursor_set_limit(&cursor, limit);
   }
   if (skip != 0) {
      mongo_cursor_set_skip(&cursor, skip);
   }

   insertMongoCursorIntoObjectMap(context, type, &cursor);

   bson_destroy(&query);
   mongo_cursor_destroy(&cursor);
}

void sobLoadAllById(sobContext context,
                    sobType type,
                    cvector oids)
{
   assert(cvectorElementSize(oids) == sizeof(bson_oid_t));

   bson query;
   bson_init(&query);
   bson_append_start_object(&query, "_id");
   bson_append_start_array(&query, "$in");

   for (unsigned int i = 0; i < cvectorCount(oids); i++) {
     char buffer[100]; // plenty big, way bigger than necessary for even 64-bit unsigned ints
     snprintf(buffer, 100, "%d", i);

     bson_append_oid(&query, buffer, (bson_oid_t *)cvectorGetElement(oids, i));
   }

   bson_append_finish_array(&query);
   bson_append_finish_object(&query);
   bson_finish(&query);
 
   // TODO: check return status
   sobConnectAndAuthenticate(context, type);
 
   mongo_cursor cursor;
   mongo_cursor_init(&cursor,
                     context->typeToConn[type], 
                     sobDBCollection[sobArrayIndex(type, context->env)]);
   mongo_cursor_set_options(&cursor, MONGO_SLAVE_OK);

   mongo_cursor_set_query(&cursor, &query);
   
   insertMongoCursorIntoObjectMap(context, type, &cursor);
   
   bson_destroy(&query);
   mongo_cursor_destroy(&cursor);
}

int sobBsonOidEqual(bson_oid_t oid1, bson_oid_t oid2)
{
   for (unsigned int i = 0; i < sizeof(bson_oid_t); i++) {
      if (oid1.bytes[i] != oid2.bytes[i]) {
         return FALSE;
      }
   }

   return TRUE;
}

int sobBsonOidFieldEqual(sobContext context,
                         sobType objectType,
                         sobField objectOidField,
                         bson_oid_t objectOid,
                         bson_oid_t oidEqual)
{
   bson_iterator iterator;
   bson_type type;
   bson *object;

   assert(sobFieldBSONType[objectOidField] == BSON_OID);

   if (!sobGetBsonByOid(context,
                        objectType,
                        objectOid,
                        &object))
   {
      return FALSE;
   }

   type = bson_find(&iterator, object, sobFieldDBName[objectOidField]);
   if (BSON_OID != type) {
      return FALSE;
   }

   return sobBsonOidEqual(*bson_iterator_oid(&iterator), oidEqual);
}

int sobGetBsonByOid(sobContext context,
                    sobType type,
                    bson_oid_t oid,
                    bson **result)
{
   cvector vec = context->objectVector[type];
  
   // slow linear search, but should be fine until we get tons of objects... 
   for (unsigned int i = 0; i < cvectorCount(vec); i++) {
      bson_iterator iterator;
      bson_type type;
      bson *object = *(bson **)cvectorGetElement(vec, i);

      if ((type = bson_find(&iterator, object, "_id"))) {
         assert(BSON_OID == type);
         if (sobBsonOidEqual(*bson_iterator_oid(&iterator), oid)) {
            *result = object;
            return TRUE;
         }
      }
   }

   return FALSE;
}

int sobGetBsonByOidField(sobContext context,
                         sobType typeToGet,
                         bson *object,
                         sobField objectOidField, 
                         bson **result)
{
   bson_iterator iterator;
   bson_type type;

   if ((type = bson_find(&iterator, object, sobFieldDBName[objectOidField]))) {
      if (BSON_OID == type) {
         bson_oid_t oidToGet = *bson_iterator_oid(&iterator);
         return sobGetBsonByOid(context, typeToGet, oidToGet, result);
      }
   }

   return FALSE;
}

void sobGetBsonVector(sobContext context,
                      sobType type,
                      cvector result)
{
   assert(cvectorElementSize(result) == sizeof(bson *));

   cvector objectVector = context->objectVector[type];

   // TODO: ideally would make this a generic copy function for all cvectors...
   for (unsigned int i = 0; i < cvectorCount(objectVector); i++) {
      cvectorAddElement(result, cvectorGetElement(objectVector, i));
   }
}

void sobGetOidVectorFromObjectField(sobContext context,
                                    sobType type,
                                    sobField field,
                                    cvector result)
{
   assert(cvectorElementSize(result) == sizeof(bson_oid_t));
   cvector objectVector = context->objectVector[type];

   for (unsigned int i = 0; i < cvectorCount(objectVector); i++) {
      bson_iterator iterator;
      bson_type type;
 
      type = bson_find(&iterator, *(bson **)cvectorGetElement(objectVector, i), sobFieldDBName[field]);
      if (type == BSON_OID) {
         cvectorAddElement(result, bson_iterator_oid(&iterator));
      }
   }
}

void sobPrintAttributes(mrjsonContext context,
                        bson *object,
                        sobField *fieldArray,
                        unsigned int numFields)
{
   for (unsigned int i = 0; i < numFields; i++) {
      sobField field = fieldArray[i];
      const char *longName = sobFieldLongName[field];

      // the name of this method is really for users...
      sobPrintAttributeWithKeyOverride(context, object, field, longName);
   }
}

void sobPrintStringToBoolAttributeWithKeyOverride(mrjsonContext context,
                                                  bson *object,
                                                  sobField field,
                                                  const char *key)
{
  mrbsonStringAsBoolAttribute(context,
                              object,
                              sobFieldDBName[field],
                              key);
}

void sobPrintAttributeWithKeyOverride(mrjsonContext context,
                                      bson *object,
                                      sobField field,
                                      const char *key)
{
   const char *dbName = sobFieldDBName[field];

   switch(sobFieldBSONType[field])
   {
      case BSON_OID:
         mrbsonOidAttribute(context, object, dbName, key);
         break;

      case BSON_DOUBLE:
         mrbsonDoubleAttribute(context, object, dbName, key);
         break;

      case BSON_STRING:
         mrbsonStringAttribute(context, object, dbName, key);
         break;

      case BSON_BOOL:
         mrbsonBoolAttribute(context, object, dbName, key);
         break;

      case BSON_NULL:
         mrjsonNullAttribute(context, key);
         break;

      case BSON_INT:
         mrbsonIntAttribute(context, object, dbName, key);
         break;
      
      case BSON_ARRAY:
         mrbsonSimpleArrayAttribute(context, object, dbName, key);
         break;

      case BSON_TIMESTAMP:
      case BSON_LONG:
      case BSON_EOO:
      case BSON_OBJECT:
      case BSON_BINDATA:
      case BSON_UNDEFINED:
      case BSON_DATE:
      case BSON_REGEX:
      case BSON_DBREF:
      case BSON_CODE:
      case BSON_SYMBOL:
      case BSON_CODEWSCOPE:
         assert(FALSE); // not implemented
         break;
   }
}

void sobPrintOidConciseTimeAgoAttribute(mrjsonContext context,
                                        bson *object,
                                        sobField oidField,
                                        const char *key)
{
   const char *dbName = sobFieldDBName[oidField];

   mrbsonOidConciseTimeAgoAttribute(context,
                                    object,
                                    dbName,
                                    key);
}

void sobPrintSubobjectByOid(sobContext sob,
                            mrjsonContext context,
                            bson *object,
                            sobField subobjectOidField,
                            sobType subobjectType,
                            const char *key,
                            sobSubobjectPrintCallback subobjectPrintCallback)
{
   bson_oid_t subobjectOid;
   bson *subobjectBson = NULL;
   const char *subobjectOidDBName = sobFieldDBName[subobjectOidField];

   if (mrbsonFindOid(object, subobjectOidDBName, &subobjectOid) &&
       sobGetBsonByOid(sob, subobjectType, subobjectOid, &subobjectBson)) {

      mrjsonStartObject(context, key);
      subobjectPrintCallback(sob, context, subobjectBson);
      mrjsonEndObject(context);

   } else {
      mrjsonNullAttribute(context, key);
   }
}

void sobPrintSubobjectArray(sobContext sob,
                            mrjsonContext context,
                            bson *object,
                            sobField objectArrayField,
                            sobSubobjectPrintCallback subobjectPrintCallback)
{
   bson arrayBson;
   const char *objectArrayDBName = sobFieldDBName[objectArrayField];

   bson_iterator iterator;
   bson_find(&iterator, object, objectArrayDBName);

   bson_iterator_subobject(&iterator, &arrayBson);
   bson_iterator_from_buffer(&iterator, arrayBson.data);

   mrjsonStartArray(context, sobFieldLongName[objectArrayField]);

   while (bson_iterator_next(&iterator)) {
      bson element;
      bson_iterator_subobject(&iterator, &element);

      mrjsonStartNamelessObject(context);
      subobjectPrintCallback(sob, context, &element);
      mrjsonEndObject(context);
   }

   mrjsonEndArray(context); 
}

void sobPrintArrayAttributeCountWithKey(mrjsonContext context,
                                        bson *object,
                                        sobField objectArrayField,
                                        const char *key)
{
   bson arrayBson;
   const char *objectArrayDBName = sobFieldDBName[objectArrayField];

   bson_iterator iterator;
   bson_find(&iterator, object, objectArrayDBName);

   bson_iterator_subobject(&iterator, &arrayBson);
   bson_iterator_from_buffer(&iterator, arrayBson.data);

   unsigned int count = 0;

   while (bson_iterator_next(&iterator)) {
      count++;
   }
   
   mrjsonIntAttribute(context, key, count);
}

int sobBsonBoolField(sobContext context,
                     sobType objectType,
                     sobField fieldToCheck,
                     bson_oid_t objectOid)
{
   bson_iterator iterator;
   bson_type type;
   bson *object;

   assert(sobFieldBSONType[fieldToCheck] == BSON_BOOL);

   if (!sobGetBsonByOid(context,
                        objectType,
                        objectOid,
                        &object))
   {
      return FALSE;
   }

   type = bson_find(&iterator, object, sobFieldDBName[fieldToCheck]);
   if (BSON_BOOL != type) {
      return FALSE;
   }

   return bson_iterator_bool(&iterator);
}

int sobBsonIntField(sobContext context,
                    sobType objectType,
                    sobField fieldToCheck,
                    bson_oid_t objectOid,
                    int *result)
{
   bson_iterator iterator;
   bson_type type;
   bson *object;

   assert(sobFieldBSONType[fieldToCheck] == BSON_INT);

   if (!sobGetBsonByOid(context,
                        objectType,
                        objectOid,
                        &object))
   {
      return FALSE;
   }

   type = bson_find(&iterator, object, sobFieldDBName[fieldToCheck]);
   if (BSON_INT != type) {
      return FALSE;
   }

   *result = bson_iterator_int(&iterator);
   return TRUE;
}

int sobBsonOidField(sobType objectType,
                    sobField fieldToCheck,
                    bson* object,
                    bson_oid_t *output)
{
   bson_iterator iterator;
   bson_type type;

   assert(sobFieldBSONType[fieldToCheck] == BSON_OID);

   type = bson_find(&iterator, object, sobFieldDBName[fieldToCheck]);
   if (BSON_OID != type) {
      return FALSE;
   }

   *output = *bson_iterator_oid(&iterator);
   return TRUE;
}

void sobPrintFieldIfBoolField(mrjsonContext context,
                              bson *object,
                              sobField fieldToPrint,
                              sobField fieldToCheck)
{
   bson_iterator iterator;
   bson_type type;
   sobField attributeToPrint[] = { fieldToPrint };

   if ((type = bson_find(&iterator, object, sobFieldDBName[fieldToCheck]))) {
      assert(BSON_BOOL == type);
      if (bson_iterator_bool(&iterator)) {
         sobPrintAttributes(context, object, attributeToPrint, 1);
      }
   }
}

int sobOidArrayFieldContainsOid(sobContext context,
                                sobField arrayField,
                                sobField fieldToCheck,
                                bson *object,
                                bson_oid_t oidToCheck)
{
   bson arrayBson;
   const char *objectArrayDBName = sobFieldDBName[arrayField];

   bson_iterator iterator;
   bson_find(&iterator, object, objectArrayDBName);

   bson_iterator_subobject(&iterator, &arrayBson);
   bson_iterator_from_buffer(&iterator, arrayBson.data);

   while (bson_iterator_next(&iterator)) {
       bson element;
       bson_type type;
       bson_iterator subIterator;
       bson_iterator_subobject(&iterator, &element);

       type = bson_find(&subIterator, &element, sobFieldDBName[fieldToCheck]);
       if (type != BSON_OID) {
          continue;
       }

      if (sobBsonOidEqual(*bson_iterator_oid(&subIterator), oidToCheck)) {
         return TRUE;
      }
   }

   return FALSE;
}

void sobGetOidVectorFromObjectArrayField(sobContext context,
                                         sobType type,
                                         sobField arrayField,
                                         sobField subObjectOidField,
                                         cvector result)
{
   assert(cvectorElementSize(result) == sizeof(bson_oid_t));
   cvector objectVector = context->objectVector[type];

   for (unsigned int i = 0; i < cvectorCount(objectVector); i++) {
      bson_iterator iterator;
      bson_type type;
 
      type = bson_find(&iterator, *(bson **)cvectorGetElement(objectVector, i), sobFieldDBName[arrayField]);
      if (type != BSON_ARRAY) {
         continue;
      }

     bson arrayBson;
     bson_iterator_subobject(&iterator, &arrayBson);
     bson_iterator_from_buffer(&iterator, arrayBson.data);

     while (bson_iterator_next(&iterator)) {
        bson element;
        bson_iterator subIterator;
        bson_iterator_subobject(&iterator, &element);

        type = bson_find(&subIterator, &element, sobFieldDBName[subObjectOidField]);
        if (type != BSON_OID) {
           continue;
        }

        cvectorAddElement(result, bson_iterator_oid(&subIterator));
     }
  }
}

int sobGetBsonForArrayObjectWithOidField(sobContext sob,
                                         sobType objectType,
                                         bson_oid_t objectOid,
                                         sobField objectField,
                                         sobField arrayObjectField,
                                         bson_oid_t oidToCheck,
                                         bson *result)
{
   cvector objectVector = sob->objectVector[objectType];
   bson *object = NULL;
   bson_type type;
   bson_iterator iterator;

   for (unsigned int i = 0; i < cvectorCount(objectVector); i++) {
      object = *(bson **)cvectorGetElement(objectVector, i);

      if ((type = bson_find(&iterator, object, "_id"))) {
         assert(BSON_OID == type);
         if (sobBsonOidEqual(*bson_iterator_oid(&iterator), objectOid)) {
            break;
         }
      }
   }

   if (NULL == object) {
      return FALSE;
   }

   type = bson_find(&iterator, object, sobFieldDBName[objectField]);

   if (type != BSON_ARRAY) {
      return FALSE;
   }
 
   bson arrayBson;
   bson_iterator_subobject(&iterator, &arrayBson);
   bson_iterator_from_buffer(&iterator, arrayBson.data);
 
   while (bson_iterator_next(&iterator)) {
      bson element;
      bson_iterator subIterator;
      bson_iterator_subobject(&iterator, &element);
 
      type = bson_find(&subIterator, &element, sobFieldDBName[arrayObjectField]);
      if (type != BSON_OID) {
         continue;
      }
 
      if (sobBsonOidEqual(*bson_iterator_oid(&subIterator), oidToCheck)) {
         *result = element;
         return TRUE;
      }
   }

   return FALSE;
}

bson_timestamp_t sobGetBsonOidTimestamp(bson_oid_t *oid)
{
  bson_timestamp_t ts;
  bson_big_endian32(&ts.t, &oid->ints[0]);
  bson_big_endian32(&ts.i, &oid->ints[2]);
  return ts;
}

unsigned int sobGetOidGenerationTimeSinceEpoch(bson *object, bson_timestamp_t *ts)
{
   bson_iterator iterator;

   if (bson_find(&iterator, object, "_id" )) {
      if (ts) {
        *ts = sobGetBsonOidTimestamp(bson_iterator_oid(&iterator));
        return ts->t;
      } else {
        return bson_oid_generated_time(bson_iterator_oid(&iterator));
      }
   } else {
      return 0;
   }
}

