#ifndef __SOB_DATABASES_H__
#define __SOB_DATABASES_H__

// ordered in the same order as sobType so that arrays get populated correctly
#define ALL_DATABASES(apply)        \
   USER_DATABASES(apply)            \
   FRAME_DATABASES(apply)           \
   ROLL_DATABASES(apply)            \
   CONVERSATION_DATABASES(apply)    \
   VIDEO_DATABASES(apply)           \
   DASHBOARD_ENTRY_DATABASES(apply) \

#define USER_DATABASES(apply)                   \
   apply(DEVELOPMENT , dev-gt-user    , users , false , , 127.0.0.1:27017 , , , ) \
   apply(TEST        , test-gt-user   , users , false , , 127.0.0.1:27017 , , , ) \
   apply(PRODUCTION  , nos-production , users , true , shelbySet , nos-db-s0-a:27018 , nos-db-s0-b:27018 , NULL, ) 

#define FRAME_DATABASES(apply)                       \
   apply(DEVELOPMENT , dev-gt-roll-frame  , frames , false , , 127.0.0.1:27017 , , , ) \
   apply(TEST        , test-gt-roll-frame , frames , false , , 127.0.0.1:27017 , , , ) \
   apply(PRODUCTION  , gt-roll-frame      , frames , true , gtRollFrame , 10.176.69.215:27017 , 10.176.69.216:27017 , gt_user , GT/us3r!!! ) 

#define ROLL_DATABASES(apply)                       \
   apply(DEVELOPMENT , dev-gt-roll-frame  , rolls , false , , 127.0.0.1:27017 , , , ) \
   apply(TEST        , test-gt-roll-frame , rolls , false , , 127.0.0.1:27017 , , , ) \
   apply(PRODUCTION  , gt-roll-frame      , rolls , true , gtRollFrame , 10.176.69.215:27017 , 10.176.69.216:27017 , gt_user , GT/us3r!!! ) 

#define CONVERSATION_DATABASES(apply)                         \
   apply(DEVELOPMENT , dev-gt-conversation  , conversations , false , , 127.0.0.1:27017 , , , ) \
   apply(TEST        , test-gt-conversation , conversations , false , , 127.0.0.1:27017 , , , ) \
   apply(PRODUCTION  , gt-conversation      , conversations , true , gtConversation , 10.176.69.208:27017 , 10.176.69.210:27017 , gt_user , GT/us3r!!! ) 

#define VIDEO_DATABASES(apply)                  \
   apply(DEVELOPMENT , dev-gt-video  , videos , false , , 127.0.0.1:27017 , , , ) \
   apply(TEST        , test-gt-video , videos , false , , 127.0.0.1:27017 , , , ) \
   apply(PRODUCTION  , gt-video      , videos , true , gtVideo , 10.176.69.184:27017 , 10.176.69.187:27017 , gt_user , GT/us3r!!! )

#define DASHBOARD_ENTRY_DATABASES(apply)                             \
   apply(DEVELOPMENT , dev-gt-dashboard-entry  , dashboard_entries , false , , 127.0.0.1:27017 , , , ) \
   apply(TEST        , test-gt-dashboard-entry , dashboard_entries , false , , 127.0.0.1:27017 , , , ) \
   apply(PRODUCTION  , gt-dashboard-entry      , dashboard_entries , true , gtDashboard , 10.183.74.78:27017 , 10.176.64.171:27017 , gt_user , GT/us3r!!! )

#endif // __SOB_DATABASES_H__
