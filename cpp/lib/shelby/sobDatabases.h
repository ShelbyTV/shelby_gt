#ifndef __SOB_DATABASES_H__
#define __SOB_DATABASES_H__

/*
 * Here we use a modified version of the "X" Macro technique. See here for an explanation:
 *
 * http://www.drdobbs.com/cpp/the-x-macro/228700289
 *
 * Format:
 *
 *   env ALL CAPS, DB name in mongo, collection name, replset?, replset name,
 *      primary server, secondary server, username, password
 *
 * NOTE:
 *
 *   All entries must have the same number of lines (environments) ordered in the same
 *   way. Client code accesses this by treating arrays like they're 2D arrays (multiplying
 *   type index * num environments + environment).
 */

// ordered in the same order as sobType so that arrays get populated correctly
#define ALL_DATABASES(apply)        \
   USER_DATABASES(apply)            \
   FRAME_DATABASES(apply)           \
   ANCESTOR_FRAME_DATABASES(apply)  \
   ROLL_DATABASES(apply)            \
   CONVERSATION_DATABASES(apply)    \
   VIDEO_DATABASES(apply)           \
   DASHBOARD_ENTRY_DATABASES(apply) \

#define USER_DATABASES(apply)                   \
   apply(DEVELOPMENT , dev-gt-user    , users , FALSE , , 127.0.0.1:27017 , , , ) \
   apply(TEST        , test-gt-user   , users , FALSE , , 127.0.0.1:27017 , , , ) \
   apply(STAGING     , nos-production , users , TRUE , shelbySet , nos-db-s0-a:27018 , nos-db-s0-b:27018 , NULL, ) \
   apply(PRODUCTION  , nos-production , users , TRUE , shelbySet , nos-db-s0-a:27018 , nos-db-s0-b:27018 , NULL, )

#define FRAME_DATABASES(apply)                       \
   apply(DEVELOPMENT , dev-gt-roll-frame  , frames , FALSE , , 127.0.0.1:27017 , , , ) \
   apply(TEST        , test-gt-roll-frame , frames , FALSE , , 127.0.0.1:27017 , , , ) \
   apply(STAGING     , gt-roll-frame      , frames , FALSE , , gt-api-a:27222  , , gt_user , GT/us3r!!! ) \
   apply(PRODUCTION  , gt-roll-frame      , frames , FALSE , , gt-api-a:27222 , , gt_user , GT/us3r!!! )

#define ANCESTOR_FRAME_DATABASES(apply)                       \
   apply(DEVELOPMENT , dev-gt-roll-frame  , frames , FALSE , , 127.0.0.1:27017 , , , ) \
   apply(TEST        , test-gt-roll-frame , frames , FALSE , , 127.0.0.1:27017 , , , ) \
   apply(STAGING     , gt-roll-frame      , frames , FALSE , , gt-api-a:27222  , , gt_user , GT/us3r!!! ) \
   apply(PRODUCTION  , gt-roll-frame      , frames , FALSE , , gt-api-a:27222 , , gt_user , GT/us3r!!! )

#define ROLL_DATABASES(apply)                       \
   apply(DEVELOPMENT , dev-gt-roll-frame  , rolls , FALSE , , 127.0.0.1:27017 , , , ) \
   apply(TEST        , test-gt-roll-frame , rolls , FALSE , , 127.0.0.1:27017 , , , ) \
   apply(STAGING     , gt-roll-frame      , rolls , FALSE , , gt-api-a:27222  , , gt_user , GT/us3r!!! ) \
   apply(PRODUCTION  , gt-roll-frame      , rolls , FALSE , , gt-api-a:27222 , , gt_user , GT/us3r!!! )

#define CONVERSATION_DATABASES(apply)                         \
   apply(DEVELOPMENT , dev-gt-conversation  , conversations , FALSE , , 127.0.0.1:27017 , , , ) \
   apply(TEST        , test-gt-conversation , conversations , FALSE , , 127.0.0.1:27017 , , , ) \
   apply(STAGING     , gt-conversation      , conversations , FALSE , , gt-api-a:27221  , , gt_user , GT/us3r!!! ) \
   apply(PRODUCTION  , gt-conversation      , conversations , FALSE , , gt-api-a:27221 , , gt_user , GT/us3r!!! )

#define VIDEO_DATABASES(apply)                  \
   apply(DEVELOPMENT , dev-gt-video  , videos , FALSE , , 127.0.0.1:27017 , , , ) \
   apply(TEST        , test-gt-video , videos , FALSE , , 127.0.0.1:27017 , , , ) \
   apply(STAGING     , gt-video      , videos , FALSE , , gt-api-a:27220  , , gt_user , GT/us3r!!! ) \
   apply(PRODUCTION  , gt-video      , videos , FALSE , , gt-api-a:27220 , , gt_user , GT/us3r!!! )

#define DASHBOARD_ENTRY_DATABASES(apply)                             \
   apply(DEVELOPMENT , dev-gt-dashboard-entry  , dashboard_entries , FALSE , , 127.0.0.1:27017 , , , ) \
   apply(TEST        , test-gt-dashboard-entry , dashboard_entries , FALSE , , 127.0.0.1:27017 , , , ) \
   apply(STAGING     , gt-dashboard-entry      , dashboard_entries , FALSE , , gt-api-a:27219  , , gt_user , GT/us3r!!! ) \
   apply(PRODUCTION  , gt-dashboard-entry      , dashboard_entries , FALSE , , gt-api-a:27219 , , gt_user , GT/us3r!!! )

#endif // __SOB_DATABASES_H__
