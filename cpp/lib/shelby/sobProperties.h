#ifndef __SOB_PROPERTIES_H__
#define __SOB_PROPERTIES_H__

/*
 * Here we use a modified version of the "X" Macro technique. See here for an explanation:
 *
 * http://www.drdobbs.com/cpp/the-x-macro/228700289
 *
 * Format:
 *
 *   default long name, default long name ALL CAPS, BSON type, database field
 *
 * TODO:
 *
 *  - not sure what to do about ARRAY typecasts (what type is in the array)
 *  - not sure about frame short_links (created as a Ruby Hash) - what's the right BSON type?
 *  - not sure about roll short_links (created as a Ruby Hash) - what's the right BSON type?
 *  - not sure about user autocomplete (created as a Ruby Hash) - what's the right BSON type?
 *  - not sure which user old keys are necessary -- not everything added yet
 */ 

#define ALL_PROPERTIES(apply) \
   VIDEO_PROPERTIES(apply) \
   FRAME_PROPERTIES(apply) \
   USER_PROPERTIES(apply) \
   DASHBOARD_ENTRY_PROPERTIES(apply) \
   CONVERSATION_PROPERTIES(apply) \
   ROLL_PROPERTIES(apply) \
   MESSAGE_PROPERTIES(apply)

#define VIDEO_PROPERTIES(apply)                               \
   apply(id               , ID               , OID    , _id ) \
   apply(provider_name    , PROVIDER_NAME    , STRING , a   ) \
   apply(provider_id      , PROVIDER_ID      , STRING , b   ) \
   apply(title            , TITLE            , STRING , c   ) \
   apply(name             , NAME             , STRING , d   ) \
   apply(description      , DESCRIPTION      , STRING , e   ) \
   apply(duration         , DURATION         , STRING , f   ) \
   apply(author           , AUTHOR           , STRING , g   ) \
   apply(video_height     , VIDEO_HEIGHT     , STRING , h   ) \
   apply(video_width      , VIDEO_WIDTH      , STRING , i   ) \
   apply(thumbnail_url    , THUMBNAIL_URL    , STRING , j   ) \
   apply(thumbnail_height , THUMBNAIL_HEIGHT , STRING , k   ) \
   apply(thumbnail_width  , THUMBNAIL_WIDTH  , STRING , l   ) \
   apply(tags             , TAGS             , ARRAY  , m   ) \
   apply(categories       , CATEGORIES       , ARRAY  , n   ) \
   apply(source_url       , SOURCE_URL       , STRING , o   ) \
   apply(embed_url        , EMBED_URL        , STRING , p   ) \
   apply(view_count       , VIEW_COUNT       , INT    , q   ) \
   apply(recs             , RECS             , ARRAY  , r   )

#define FRAME_PROPERTIES(apply)                             \
   apply(id              , ID              , OID    , _id ) \
   apply(roll_id         , ROLL_ID         , OID    , a   ) \
   apply(video_id        , VIDEO_ID        , OID    , b   ) \
   apply(conversation_id , CONVERSATION_ID , OID    , c   ) \
   apply(creator_id      , CREATOR_ID      , OID    , d   ) \
   apply(score           , SCORE           , DOUBLE , e   ) \
   apply(upvoters        , UPVOTERS        , ARRAY  , f   ) \
   apply(frame_ancestors , FRAME_ANCESTORS , ARRAY  , g   ) \
   apply(frame_children  , FRAME_CHILDREN  , ARRAY  , h   ) \
   apply(view_count      , VIEW_COUNT      , INT    , i   ) \
   apply(short_links     , SHORT_LINKS     , ARRAY  , j   ) \
   apply(order           , ORDER           , DOUBLE , k   )

#define USER_PROPERTIES(apply)                                                          \
   apply(id                   ,  ID                   ,  OID    , _id                 ) \
   apply(rolls_unfollowed     ,  ROLLS_UNFOLLOWED     ,  ARRAY  , aa                  ) \
   apply(public_roll_id       ,  PUBLIC_ROLL_ID       ,  OID    , ab                  ) \
   apply(watch_later_roll_id  ,  WATCH_LATER_ROLL_ID  ,  OID    , ad                  ) \
   apply(upvoted_roll_id      ,  UPVOTED_ROLL_ID      ,  OID    , ae                  ) \
   apply(viewed_roll_id       ,  VIEWED_ROLL_ID       ,  OID    , af                  ) \
   apply(faux                 ,  FAUX                 ,  INT    , ac                  ) \
   apply(authentication_token ,  AUTHENTICATION_TOKEN ,  STRING , ah                  ) \
   apply(gt_enabled           ,  GT_ENABLED           ,  BOOL   , ag                  ) \
   apply(applications         ,  APPLICATIONS         ,  ARRAY  , ap                  ) \
   apply(clients              ,  CLIENTS              ,  ARRAY  , ai                  ) \
   apply(cohorts              ,  COHORTS              ,  ARRAY  , aq                  ) \
   apply(autocomplete         ,  AUTOCOMPLETE         ,  ARRAY  , as                  ) \
   apply(name                 ,  NAME                 ,  STRING , name                ) \
   apply(nickname             ,  NICKNAME             ,  STRING , nickname            ) \
   apply(downcase_nickname    ,  DOWNCASE_NICKNAME    ,  STRING , downcase_nickname   ) \
   apply(user_image           ,  USER_IMAGE           ,  STRING , user_image          ) \
   apply(user_image_original  ,  USER_IMAGE_ORIGINAL  ,  STRING , user_image_original ) \
   apply(primary_email        ,  PRIMARY_EMAIL        ,  STRING , primary_email       ) \
   apply(encrypted_password   ,  ENCRYPTED_PASSWORD   ,  STRING , ar                  ) \
   apply(server_created_on    ,  SERVER_CREATED_ON    ,  STRING , server_created_on   ) \
   apply(referral_frame_id    ,  REFERRAL_FRAME_ID    ,  OID    , referral_frame_id   ) \
   apply(is_admin             ,  IS_ADMIN             ,  BOOL   , is_admin            ) \
   apply(social_tracker       ,  SOCIAL_TRACKER       ,  ARRAY  , social_tracker      )

#define DASHBOARD_ENTRY_PROPERTIES(apply)   \
   apply(id       , ID       , OID  , _id ) \
   apply(user_id  , USER_ID  , OID  , a   ) \
   apply(roll_id  , ROLL_ID  , OID  , b   ) \
   apply(frame_id , FRAME_ID , OID  , c   ) \
   apply(read     , READ     , BOOL , d   ) \
   apply(action   , ACTION   , INT  , e   ) \
   apply(actor_id , ACTOR_ID , OID  , f   )

#define CONVERSATION_PROPERTIES(apply)                \
   apply(id            , ID            , OID  , _id ) \
   apply(video_id      , VIDEO_ID      , OID  , a   ) \
   apply(public        , PUBLIC        , BOOL , b   ) \
   apply(frame_id      , FRAME_ID      , OID  , c   ) \
   apply(from_deeplink , FROM_DEEPLINK , BOOL , d   )
 
#define ROLL_PROPERTIES(apply)                                                  \
   apply(id                        , ID                        , OID    , _id ) \
   apply(creator_id                , CREATOR_ID                , OID    , a   ) \
   apply(title                     , TITLE                     , STRING , b   ) \
   apply(creator_thumbnail_url     , CREATOR_THUMBNAIL_URL     , STRING , c   ) \
   apply(public                    , PUBLIC                    , BOOL   , d   ) \
   apply(collaborative             , COLLABORATIVE             , BOOL   , e   ) \
   apply(origin_network            , ORIGIN_NETWORK            , STRING , f   ) \
   apply(short_links               , SHORT_LINKS               , ARRAY  , g   ) \
   apply(genius                    , GENIUS                    , BOOL   , h   ) \
   apply(upvoted_roll              , UPVOTED_ROLL              , BOOL   , i   ) \
   apply(frame_count               , FRAME_COUNT               , INT    , j   ) \
   apply(subdomain                 , SUBDOMAIN                 , STRING , k   ) \
   apply(subdomain_active          , SUBDOMAIN_ACTIVE          , BOOL   , l   ) \
   apply(first_frame_thumbnail_url , FIRST_FRAME_THUMBNAIL_URL , STRING , m   ) \
   apply(roll_type                 , ROLL_TYPE                 , INT    , n   )

#define MESSAGE_PROPERTIES(apply)                         \
   apply(id             , ID             , OID    , _id ) \
   apply(origin_network , ORIGIN_NETWORK , STRING , a   ) \
   apply(origin_id      , ORIGIN_ID      , STRING , b   ) \
   apply(origin_user_id , ORIGIN_USER_ID , STRING , c   ) \
   apply(user_id        , USER_ID        , OID    , d   ) \
   apply(nickname       , NICKNAME       , STRING , e   ) \
   apply(realname       , REALNAME       , STRING , f   ) \
   apply(user_image_url , USER_IMAGE_URL , STRING , g   ) \
   apply(text           , TEXT           , STRING , h   ) \
   apply(public         , PUBLIC         , BOOL   , i   )


#endif // __SOB_PROPERTIES_H__
