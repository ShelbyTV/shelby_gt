#ifndef __SOB_PROPERTIES_H__
#define __SOB_PROPERTIES_H__

/*
 * Here we use a modified version of the "X" Macro technique. See here for an explanation:
 *
 * http://www.drdobbs.com/cpp/the-x-macro/228700289
 *
 * Format:
 *
 *   type ALL CAPS, default long name, default long name ALL CAPS, BSON type, database field
 *
 * TODO:
 *
 *  - not sure what to do about ARRAY typecasts (what type is in the array)
 *  - not sure about frame short_links (created as a Ruby Hash) - what's the right BSON type? -> it's an embedded (BSON) Document
 *  - not sure about roll short_links (created as a Ruby Hash) - what's the right BSON type?
 *  - not sure about user autocomplete (created as a Ruby Hash) - what's the right BSON type?
 *  - not sure which user old keys are necessary -- not everything added yet
 */

#define ALL_PROPERTIES(apply)        \
   USER_PROPERTIES(apply)            \
   CREATOR_PROPERTIES(apply)         \
   ORIGINATOR_PROPERTIES(apply)      \
   ACTOR_PROPERTIES(apply)           \
   FRAME_PROPERTIES(apply)           \
   ANCESTOR_FRAME_PROPERTIES(apply)  \
   ROLL_PROPERTIES(apply)            \
   CONVERSATION_PROPERTIES(apply)    \
   VIDEO_PROPERTIES(apply)           \
   DASHBOARD_ENTRY_PROPERTIES(apply) \
   MESSAGE_PROPERTIES(apply)         \
   ROLL_FOLLOWING_PROPERTIES(apply)  \
   FOLLOWING_USER_PROPERTIES(apply)  \
   AUTHENTICATION_PROPERTIES(apply)  \
   RECOMMENDATION_PROPERTIES(apply)

#define USER_PROPERTIES(apply)                                                                 \
   apply(USER , id                   ,  ID                   ,  OID    , _id                 ) \
   apply(USER , rolls_unfollowed     ,  ROLLS_UNFOLLOWED     ,  ARRAY  , aa                  ) \
   apply(USER , public_roll_id       ,  PUBLIC_ROLL_ID       ,  OID    , ab                  ) \
   apply(USER , watch_later_roll_id  ,  WATCH_LATER_ROLL_ID  ,  OID    , ad                  ) \
   apply(USER , upvoted_roll_id      ,  UPVOTED_ROLL_ID      ,  OID    , ae                  ) \
   apply(USER , viewed_roll_id       ,  VIEWED_ROLL_ID       ,  OID    , af                  ) \
   apply(USER , user_type            ,  USER_TYPE            ,  INT    , ac                  ) \
   apply(USER , authentication_token ,  AUTHENTICATION_TOKEN ,  STRING , ah                  ) \
   apply(USER , gt_enabled           ,  GT_ENABLED           ,  BOOL   , ag                  ) \
   apply(USER , applications         ,  APPLICATIONS         ,  ARRAY  , ap                  ) \
   apply(USER , clients              ,  CLIENTS              ,  ARRAY  , ai                  ) \
   apply(USER , cohorts              ,  COHORTS              ,  ARRAY  , aq                  ) \
   apply(USER , autocomplete         ,  AUTOCOMPLETE         ,  ARRAY  , as                  ) \
   apply(USER , avatar_file_name     ,  AVATAR_FILE_NAME     ,  STRING , at                  ) \
   apply(USER , avatar_updated_at    ,  AVATAR_UPDATED_AT    ,  STRING , aw                  ) \
   apply(USER , name                 ,  NAME                 ,  STRING , name                ) \
   apply(USER , nickname             ,  NICKNAME             ,  STRING , nickname            ) \
   apply(USER , downcase_nickname    ,  DOWNCASE_NICKNAME    ,  STRING , downcase_nickname   ) \
   apply(USER , user_image           ,  USER_IMAGE           ,  STRING , user_image          ) \
   apply(USER , user_image_original  ,  USER_IMAGE_ORIGINAL  ,  STRING , user_image_original ) \
   apply(USER , primary_email        ,  PRIMARY_EMAIL        ,  STRING , primary_email       ) \
   apply(USER , encrypted_password   ,  ENCRYPTED_PASSWORD   ,  STRING , ar                  ) \
   apply(USER , server_created_on    ,  SERVER_CREATED_ON    ,  STRING , server_created_on   ) \
   apply(USER , referral_frame_id    ,  REFERRAL_FRAME_ID    ,  OID    , referral_frame_id   ) \
   apply(USER , is_admin             ,  IS_ADMIN             ,  BOOL   , is_admin            ) \
   apply(USER , social_tracker       ,  SOCIAL_TRACKER       ,  ARRAY  , social_tracker      ) \
   apply(USER , roll_followings      ,  ROLL_FOLLOWINGS      ,  ARRAY  , roll_followings     ) \
   apply(USER , authentications      ,  AUTHENTICATIONS      ,  ARRAY  , authentications     )

#define CREATOR_PROPERTIES(apply)                                                                 \
   apply(CREATOR , id                   ,  ID                   ,  OID    , _id                 ) \
   apply(CREATOR , rolls_unfollowed     ,  ROLLS_UNFOLLOWED     ,  ARRAY  , aa                  ) \
   apply(CREATOR , public_roll_id       ,  PUBLIC_ROLL_ID       ,  OID    , ab                  ) \
   apply(CREATOR , watch_later_roll_id  ,  WATCH_LATER_ROLL_ID  ,  OID    , ad                  ) \
   apply(CREATOR , upvoted_roll_id      ,  UPVOTED_ROLL_ID      ,  OID    , ae                  ) \
   apply(CREATOR , viewed_roll_id       ,  VIEWED_ROLL_ID       ,  OID    , af                  ) \
   apply(CREATOR , user_type            ,  USER_TYPE            ,  INT    , ac                  ) \
   apply(CREATOR , authentication_token ,  AUTHENTICATION_TOKEN ,  STRING , ah                  ) \
   apply(CREATOR , gt_enabled           ,  GT_ENABLED           ,  BOOL   , ag                  ) \
   apply(CREATOR , applications         ,  APPLICATIONS         ,  ARRAY  , ap                  ) \
   apply(CREATOR , clients              ,  CLIENTS              ,  ARRAY  , ai                  ) \
   apply(CREATOR , cohorts              ,  COHORTS              ,  ARRAY  , aq                  ) \
   apply(CREATOR , autocomplete         ,  AUTOCOMPLETE         ,  ARRAY  , as                  ) \
   apply(CREATOR , avatar_file_name     ,  AVATAR_FILE_NAME     ,  STRING , at                  ) \
   apply(CREATOR , avatar_updated_at    ,  AVATAR_UPDATED_AT    ,  STRING , aw                  ) \
   apply(CREATOR , name                 ,  NAME                 ,  STRING , name                ) \
   apply(CREATOR , nickname             ,  NICKNAME             ,  STRING , nickname            ) \
   apply(CREATOR , downcase_nickname    ,  DOWNCASE_NICKNAME    ,  STRING , downcase_nickname   ) \
   apply(CREATOR , user_image           ,  USER_IMAGE           ,  STRING , user_image          ) \
   apply(CREATOR , user_image_original  ,  USER_IMAGE_ORIGINAL  ,  STRING , user_image_original ) \
   apply(CREATOR , primary_email        ,  PRIMARY_EMAIL        ,  STRING , primary_email       ) \
   apply(CREATOR , encrypted_password   ,  ENCRYPTED_PASSWORD   ,  STRING , ar                  ) \
   apply(CREATOR , server_created_on    ,  SERVER_CREATED_ON    ,  STRING , server_created_on   ) \
   apply(CREATOR , referral_frame_id    ,  REFERRAL_FRAME_ID    ,  OID    , referral_frame_id   ) \
   apply(CREATOR , is_admin             ,  IS_ADMIN             ,  BOOL   , is_admin            ) \
   apply(CREATOR , social_tracker       ,  SOCIAL_TRACKER       ,  ARRAY  , social_tracker      ) \
   apply(CREATOR , roll_followings      ,  ROLL_FOLLOWINGS      ,  ARRAY  , roll_followings     ) \
   apply(CREATOR , authentications      ,  AUTHENTICATIONS      ,  ARRAY  , authentications     )

#define ORIGINATOR_PROPERTIES(apply)                                                                 \
   apply(ORIGINATOR , id                   ,  ID                   ,  OID    , _id                 ) \
   apply(ORIGINATOR , rolls_unfollowed     ,  ROLLS_UNFOLLOWED     ,  ARRAY  , aa                  ) \
   apply(ORIGINATOR , public_roll_id       ,  PUBLIC_ROLL_ID       ,  OID    , ab                  ) \
   apply(ORIGINATOR , watch_later_roll_id  ,  WATCH_LATER_ROLL_ID  ,  OID    , ad                  ) \
   apply(ORIGINATOR , upvoted_roll_id      ,  UPVOTED_ROLL_ID      ,  OID    , ae                  ) \
   apply(ORIGINATOR , viewed_roll_id       ,  VIEWED_ROLL_ID       ,  OID    , af                  ) \
   apply(ORIGINATOR , user_type            ,  USER_TYPE            ,  INT    , ac                  ) \
   apply(ORIGINATOR , authentication_token ,  AUTHENTICATION_TOKEN ,  STRING , ah                  ) \
   apply(ORIGINATOR , gt_enabled           ,  GT_ENABLED           ,  BOOL   , ag                  ) \
   apply(ORIGINATOR , applications         ,  APPLICATIONS         ,  ARRAY  , ap                  ) \
   apply(ORIGINATOR , clients              ,  CLIENTS              ,  ARRAY  , ai                  ) \
   apply(ORIGINATOR , cohorts              ,  COHORTS              ,  ARRAY  , aq                  ) \
   apply(ORIGINATOR , autocomplete         ,  AUTOCOMPLETE         ,  ARRAY  , as                  ) \
   apply(ORIGINATOR , avatar_file_name     ,  AVATAR_FILE_NAME     ,  STRING , at                  ) \
   apply(ORIGINATOR , avatar_updated_at    ,  AVATAR_UPDATED_AT    ,  STRING , aw                  ) \
   apply(ORIGINATOR , name                 ,  NAME                 ,  STRING , name                ) \
   apply(ORIGINATOR , nickname             ,  NICKNAME             ,  STRING , nickname            ) \
   apply(ORIGINATOR , downcase_nickname    ,  DOWNCASE_NICKNAME    ,  STRING , downcase_nickname   ) \
   apply(ORIGINATOR , user_image           ,  USER_IMAGE           ,  STRING , user_image          ) \
   apply(ORIGINATOR , user_image_original  ,  USER_IMAGE_ORIGINAL  ,  STRING , user_image_original ) \
   apply(ORIGINATOR , primary_email        ,  PRIMARY_EMAIL        ,  STRING , primary_email       ) \
   apply(ORIGINATOR , encrypted_password   ,  ENCRYPTED_PASSWORD   ,  STRING , ar                  ) \
   apply(ORIGINATOR , server_created_on    ,  SERVER_CREATED_ON    ,  STRING , server_created_on   ) \
   apply(ORIGINATOR , referral_frame_id    ,  REFERRAL_FRAME_ID    ,  OID    , referral_frame_id   ) \
   apply(ORIGINATOR , is_admin             ,  IS_ADMIN             ,  BOOL   , is_admin            ) \
   apply(ORIGINATOR , social_tracker       ,  SOCIAL_TRACKER       ,  ARRAY  , social_tracker      ) \
   apply(ORIGINATOR , roll_followings      ,  ROLL_FOLLOWINGS      ,  ARRAY  , roll_followings     ) \
   apply(ORIGINATOR , authentications      ,  AUTHENTICATIONS      ,  ARRAY  , authentications     )

#define ACTOR_PROPERTIES(apply)                                                                 \
   apply(ACTOR , id                   ,  ID                   ,  OID    , _id                 ) \
   apply(ACTOR , rolls_unfollowed     ,  ROLLS_UNFOLLOWED     ,  ARRAY  , aa                  ) \
   apply(ACTOR , public_roll_id       ,  PUBLIC_ROLL_ID       ,  OID    , ab                  ) \
   apply(ACTOR , watch_later_roll_id  ,  WATCH_LATER_ROLL_ID  ,  OID    , ad                  ) \
   apply(ACTOR , upvoted_roll_id      ,  UPVOTED_ROLL_ID      ,  OID    , ae                  ) \
   apply(ACTOR , viewed_roll_id       ,  VIEWED_ROLL_ID       ,  OID    , af                  ) \
   apply(ACTOR , user_type            ,  USER_TYPE            ,  INT    , ac                  ) \
   apply(ACTOR , authentication_token ,  AUTHENTICATION_TOKEN ,  STRING , ah                  ) \
   apply(ACTOR , gt_enabled           ,  GT_ENABLED           ,  BOOL   , ag                  ) \
   apply(ACTOR , applications         ,  APPLICATIONS         ,  ARRAY  , ap                  ) \
   apply(ACTOR , clients              ,  CLIENTS              ,  ARRAY  , ai                  ) \
   apply(ACTOR , cohorts              ,  COHORTS              ,  ARRAY  , aq                  ) \
   apply(ACTOR , autocomplete         ,  AUTOCOMPLETE         ,  ARRAY  , as                  ) \
   apply(ACTOR , avatar_file_name     ,  AVATAR_FILE_NAME     ,  STRING , at                  ) \
   apply(ACTOR , avatar_updated_at    ,  AVATAR_UPDATED_AT    ,  STRING , aw                  ) \
   apply(ACTOR , name                 ,  NAME                 ,  STRING , name                ) \
   apply(ACTOR , nickname             ,  NICKNAME             ,  STRING , nickname            ) \
   apply(ACTOR , downcase_nickname    ,  DOWNCASE_NICKNAME    ,  STRING , downcase_nickname   ) \
   apply(ACTOR , user_image           ,  USER_IMAGE           ,  STRING , user_image          ) \
   apply(ACTOR , user_image_original  ,  USER_IMAGE_ORIGINAL  ,  STRING , user_image_original ) \
   apply(ACTOR , primary_email        ,  PRIMARY_EMAIL        ,  STRING , primary_email       ) \
   apply(ACTOR , encrypted_password   ,  ENCRYPTED_PASSWORD   ,  STRING , ar                  ) \
   apply(ACTOR , server_created_on    ,  SERVER_CREATED_ON    ,  STRING , server_created_on   ) \
   apply(ACTOR , referral_frame_id    ,  REFERRAL_FRAME_ID    ,  OID    , referral_frame_id   ) \
   apply(ACTOR , is_admin             ,  IS_ADMIN             ,  BOOL   , is_admin            ) \
   apply(ACTOR , social_tracker       ,  SOCIAL_TRACKER       ,  ARRAY  , social_tracker      ) \
   apply(ACTOR , roll_followings      ,  ROLL_FOLLOWINGS      ,  ARRAY  , roll_followings     ) \
   apply(ACTOR , authentications      ,  AUTHENTICATIONS      ,  ARRAY  , authentications     )

#define FRAME_PROPERTIES(apply)                                                                       \
   apply(FRAME , id                         , ID                         , OID    , _id             ) \
   apply(FRAME , roll_id                    , ROLL_ID                    , OID    , a               ) \
   apply(FRAME , video_id                   , VIDEO_ID                   , OID    , b               ) \
   apply(FRAME , conversation_id            , CONVERSATION_ID            , OID    , c               ) \
   apply(FRAME , creator_id                 , CREATOR_ID                 , OID    , d               ) \
   apply(FRAME , originator_id              , ORIGINATOR_ID              , OID    , originator_id   ) \
   apply(FRAME , score                      , SCORE                      , DOUBLE , e               ) \
   apply(FRAME , upvoters                   , UPVOTERS                   , ARRAY  , f               ) \
   apply(FRAME , frame_ancestors            , FRAME_ANCESTORS            , ARRAY  , g               ) \
   apply(FRAME , frame_children             , FRAME_CHILDREN             , ARRAY  , h               ) \
   apply(FRAME , view_count                 , VIEW_COUNT                 , INT    , i               ) \
   apply(FRAME , short_links                , SHORT_LINKS                , ARRAY  , j               ) \
   apply(FRAME , order                      , ORDER                      , DOUBLE , k               ) \
   apply(FRAME , anonymous_creator_nickname , ANONYMOUS_CREATOR_NICKNAME , STRING , m               ) \
   apply(FRAME , like_count                 , LIKE_COUNT                 , INT    , n               ) \
   apply(FRAME , frame_type                 , FRAME_TYPE                 , INT    , o               ) \
   apply(FRAME , original_source_url        , ORIGINAL_SOURCE_URL        , STRING , p               )

#define ANCESTOR_FRAME_PROPERTIES(apply)                     \
   apply(ANCESTOR_FRAME , id        , ID        , OID, _id ) \
   apply(ANCESTOR_FRAME , creator_id, CREATOR_ID, OID, d   ) \

#define ROLL_PROPERTIES(apply)                                                                           \
   apply(ROLL , id                           , ID                           , OID    , _id             ) \
   apply(ROLL , creator_id                   , CREATOR_ID                   , OID    , a               ) \
   apply(ROLL , title                        , TITLE                        , STRING , b               ) \
   apply(ROLL , creator_thumbnail_url        , CREATOR_THUMBNAIL_URL        , STRING , c               ) \
   apply(ROLL , public                       , PUBLIC                       , BOOL   , d               ) \
   apply(ROLL , collaborative                , COLLABORATIVE                , BOOL   , e               ) \
   apply(ROLL , origin_network               , ORIGIN_NETWORK               , STRING , f               ) \
   apply(ROLL , short_links                  , SHORT_LINKS                  , ARRAY  , g               ) \
   apply(ROLL , genius                       , GENIUS                       , BOOL   , h               ) \
   apply(ROLL , upvoted_roll                 , UPVOTED_ROLL                 , BOOL   , i               ) \
   apply(ROLL , frame_count                  , FRAME_COUNT                  , INT    , j               ) \
   apply(ROLL , subdomain                    , SUBDOMAIN                    , STRING , k               ) \
   apply(ROLL , subdomain_active             , SUBDOMAIN_ACTIVE             , BOOL   , l               ) \
   apply(ROLL , first_frame_thumbnail_url    , FIRST_FRAME_THUMBNAIL_URL    , STRING , m               ) \
   apply(ROLL , roll_type                    , ROLL_TYPE                    , INT    , n               ) \
   apply(ROLL , header_image_file_name       , HEADER_IMAGE_FILE_NAME       , STRING , o               ) \
   apply(ROLL , discussion_roll_participants , DISCUSSION_ROLL_PARTICIPANTS , ARRAY  , s               ) \
   apply(ROLL , following_users              , FOLLOWING_USERS              , ARRAY  , following_users )

#define CONVERSATION_PROPERTIES(apply)                                     \
   apply(CONVERSATION , id            , ID            , OID   , _id      ) \
   apply(CONVERSATION , video_id      , VIDEO_ID      , OID   , a        ) \
   apply(CONVERSATION , public        , PUBLIC        , BOOL  , b        ) \
   apply(CONVERSATION , frame_id      , FRAME_ID      , OID   , c        ) \
   apply(CONVERSATION , from_deeplink , FROM_DEEPLINK , BOOL  , d        ) \
   apply(CONVERSATION , messages      , MESSAGES      , ARRAY , messages )

#define VIDEO_PROPERTIES(apply)                                                \
   apply(VIDEO , id                  , ID                  , OID       , _id ) \
   apply(VIDEO , provider_name       , PROVIDER_NAME       , STRING    , a   ) \
   apply(VIDEO , provider_id         , PROVIDER_ID         , STRING    , b   ) \
   apply(VIDEO , title               , TITLE               , STRING    , c   ) \
   apply(VIDEO , name                , NAME                , STRING    , d   ) \
   apply(VIDEO , description         , DESCRIPTION         , STRING    , e   ) \
   apply(VIDEO , duration            , DURATION            , STRING    , f   ) \
   apply(VIDEO , author              , AUTHOR              , STRING    , g   ) \
   apply(VIDEO , video_height        , VIDEO_HEIGHT        , STRING    , h   ) \
   apply(VIDEO , video_width         , VIDEO_WIDTH         , STRING    , i   ) \
   apply(VIDEO , thumbnail_url       , THUMBNAIL_URL       , STRING    , j   ) \
   apply(VIDEO , thumbnail_height    , THUMBNAIL_HEIGHT    , STRING    , k   ) \
   apply(VIDEO , thumbnail_width     , THUMBNAIL_WIDTH     , STRING    , l   ) \
   apply(VIDEO , tags                , TAGS                , ARRAY     , m   ) \
   apply(VIDEO , categories          , CATEGORIES          , ARRAY     , n   ) \
   apply(VIDEO , source_url          , SOURCE_URL          , STRING    , o   ) \
   apply(VIDEO , embed_url           , EMBED_URL           , STRING    , p   ) \
   apply(VIDEO , view_count          , VIEW_COUNT          , INT       , q   ) \
   apply(VIDEO , recs                , RECS                , ARRAY     , r   ) \
   apply(VIDEO , first_unplayable_at , FIRST_UNPLAYABLE_AT , DATE      , s   ) \
   apply(VIDEO , last_unplayable_at  , LAST_UNPLAYABLE_AT  , DATE      , t   ) \
   apply(VIDEO , like_count          , LIKE_COUNT          , INT       , v   ) \
   apply(VIDEO , tracked_liker_count , TRACKED_LIKER_COUNT , INT       , y   )

#define DASHBOARD_ENTRY_PROPERTIES(apply)                                                                \
   apply(DASHBOARD_ENTRY , id                            , ID                            , OID   , _id ) \
   apply(DASHBOARD_ENTRY , user_id                       , USER_ID                       , OID   , a   ) \
   apply(DASHBOARD_ENTRY , roll_id                       , ROLL_ID                       , OID   , b   ) \
   apply(DASHBOARD_ENTRY , frame_id                      , FRAME_ID                      , OID   , c   ) \
   apply(DASHBOARD_ENTRY , src_frame_id                  , SRC_FRAME_ID                  , OID   , i   ) \
   apply(DASHBOARD_ENTRY , src_video_id                  , SRC_VIDEO_ID                  , OID   , j   ) \
   apply(DASHBOARD_ENTRY , read                          , READ                          , BOOL  , d   ) \
   apply(DASHBOARD_ENTRY , action                        , ACTION                        , INT   , e   ) \
   apply(DASHBOARD_ENTRY , actor_id                      , ACTOR_ID                      , OID   , f   ) \
   apply(DASHBOARD_ENTRY , friend_sharers_array          , FRIEND_SHARERS_ARRAY          , ARRAY , a1  ) \
   apply(DASHBOARD_ENTRY , friend_viewers_array          , FRIEND_VIEWERS_ARRAY          , ARRAY , a2  ) \
   apply(DASHBOARD_ENTRY , friend_likers_array           , FRIEND_LIKERS_ARRAY           , ARRAY , a3  ) \
   apply(DASHBOARD_ENTRY , friend_rollers_array          , FRIEND_ROLLERS_ARRAY          , ARRAY , a4  ) \
   apply(DASHBOARD_ENTRY , friend_complete_viewers_array , FRIEND_COMPLETE_VIEWERS_ARRAY , ARRAY , a5  )

#define MESSAGE_PROPERTIES(apply)                                                    \
   apply(MESSAGE , id                     , ID                      , OID    , _id ) \
   apply(MESSAGE , origin_network         , ORIGIN_NETWORK          , STRING , a   ) \
   apply(MESSAGE , origin_id              , ORIGIN_ID               , STRING , b   ) \
   apply(MESSAGE , origin_user_id         , ORIGIN_USER_ID          , STRING , c   ) \
   apply(MESSAGE , user_id                , USER_ID                 , OID    , d   ) \
   apply(MESSAGE , nickname               , NICKNAME                , STRING , e   ) \
   apply(MESSAGE , realname               , REALNAME                , STRING , f   ) \
   apply(MESSAGE , user_image_url         , USER_IMAGE_URL          , STRING , g   ) \
   apply(MESSAGE , text                   , TEXT                    , STRING , h   ) \
   apply(MESSAGE , public                 , PUBLIC                  , BOOL   , i   ) \
   apply(MESSAGE , user_has_shelby_avatar , USER_HAS_SHELBY_AVATAR  , BOOL   , j   )

#define ROLL_FOLLOWING_PROPERTIES(apply)                  \
   apply(ROLL_FOLLOWING , id      , ID      , OID , _id ) \
   apply(ROLL_FOLLOWING , roll_id , ROLL_ID , OID , a   )

#define FOLLOWING_USER_PROPERTIES(apply)                  \
   apply(FOLLOWING_USER , id      , ID      , OID , _id ) \
   apply(FOLLOWING_USER , user_id , USER_ID , OID , a   )

#define AUTHENTICATION_PROPERTIES(apply)                             \
   apply(AUTHENTICATION , id       , ID       , OID    , _id       ) \
   apply(AUTHENTICATION , provider , PROVIDER , STRING , provider  ) \
   apply(AUTHENTICATION , uid      , UID      , STRING , uid       ) \
   apply(AUTHENTICATION , nickname , NICKNAME , STRING , nickname  ) \
   apply(AUTHENTICATION , name     , NAME     , STRING , name      )

#define RECOMMENDATION_PROPERTIES(apply)                                               \
   apply(RECOMMENDATION , id                   , ID                   , OID    , _id ) \
   apply(RECOMMENDATION , recommended_video_id , RECOMMENDED_VIDEO_ID , OID    , a   ) \
   apply(RECOMMENDATION , score                , SCORE                , DOUBLE , b   )

#endif // __SOB_PROPERTIES_H__
