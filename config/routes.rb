ShelbyGt::Application.routes.draw do
  # The priority is based upon order of creation:
  # first created -> highest priority.

  ########################
  # Authentication and User Managment

  devise_for :user, :skip => [:sessions], :controllers => {:passwords => "password_reset"}
  as :user do
    get 'signout' => 'devise/sessions#destroy', :as => :destroy_user_session
    get 'login' => 'authentications#index', :as => :new_user_session
  end

  resources :authentications do
    post 'login' => 'authentications#login', :on => :collection
    get 'should_merge' => 'authentications#should_merge_accounts', :on => :collection, :as => :should_merge_accounts
    post 'do_merge' => 'authentications#do_merge_accounts', :on => :collection, :as => :do_merge_accounts
  end
  get '/auth/:provider/callback' => 'authentications#create'
  get '/auth/failure' => 'authentications#fail'
  post '/user/sign_in' => 'authentications#create', :as => :user_session


  ########################
  # OAuth Provider
  get 'oauth/authorize' => 'oauth#authorize'
  get 'oauth/grantpage' => 'oauth#grantpage'
  get 'oauth/delete' => 'oauth#delete'
  get 'oauth/grant' => 'oauth#grant'
  get 'oauth/deny' => 'oauth#deny'
  get 'oauth/login' => 'oauth#login'
  get 'oauth/register' => 'oauth#register'
  post 'oauth/register' => 'oauth#register'
  post 'oauth/create' => 'oauth#create'
  get 'oauth/gate' => 'oauth#gate'
  get 'oauth/index' => 'oauth#index'
  get 'oauth/clientpage' => 'oauth#clientpage'

  ########################
  # Namespace allows for versioning of API
  # NOTE: Must use V1::ControllerName in controllers
  namespace :v1, :defaults => { :format => 'json' } do

    #
    # WHEN ADDING NEW NON-GET ROUTES
    #
    # Be sure to add a /v1/VERB/your-route-here route down below
    #
    # WHY? We support some browsers that don't suppot CORS, and they use jsonp which only does GETs.
    # Sometimes we have the same route do different things depending on the verb, and that doens't play nice w/ jsonp.

    resources :user, :only => [:index, :update] do
      # constraints allows for nicknames that include dots, prevents changing format (we're json only, that's ok).
      get ':id' => 'user#show', :as => :show, :on => :collection, :constraints => { :id => /[^\/]+/ }
      get 'is_token_valid' => 'user#valid_token', :on => :member
      get 'rolls/following' => 'user_metal#roll_followings', :on => :member
      get 'rolls/postable' => 'user_metal#roll_followings', :on => :member, :defaults => { :postable => true }
      get 'rolls/personal' => 'roll#show_users_public_roll'
      get 'rolls/personal/frames' => 'frame_metal#index_for_users_public_roll'
    end
    resources :roll, :only => [:index, :show, :create, :update, :destroy] do
      get 'frames' => 'frame_metal#index'
      post 'frames' => 'frame#create'
      post 'share' => 'roll#share'
      post 'join' => 'roll#join'
      post 'leave' => 'roll#leave'
      get 'explore' => 'roll#explore', :on => :collection
      get 'featured' => 'roll#featured', :on => :collection
      get 'associated' => 'roll#index_associated'
    end
    namespace :roll do
       resources :genius, :only => [:create]
    end
    resources :frame, :only => [:show, :destroy] do
      post 'upvote' => 'frame#upvote'
      post 'add_to_watch_later' => 'frame#add_to_watch_later'
      put 'like' => 'frame#like'
      post 'watched' => 'frame#watched'
      post 'share' => 'frame#share'
      get 'short_link' => 'frame#short_link'
    end
    resources :video, :only => [:show] do
      get 'find_or_create', :on => :collection
      get 'conversations' => 'conversation_metal#index'
      get 'viewed', :on => :collection
      get 'queued', :on => :collection
      get 'search' => 'video#search', :on => :collection
      put 'unplayable'
    end
    resources :dashboard_entries, :path => "dashboard", :only => [:update] do
      get 'find_entries_with_video' => 'dashboard_entries#find_entries_with_video', :on => :collection
    end
    resources :dashboard_entries_metal, :path => "dashboard", :only => [:index]
    resources :conversation, :only => [:show] do
      resources :messages, :only => [:create, :destroy]
    end
    resources :discussion_roll, :only => [:index, :create, :show] do
      post 'messages' => 'discussion_roll#create_message'
    end
    resources :beta_invite, :only => [:create]

    resources :gt_interest, :only => [:create]

    resources :token, :only => [:create, :destroy]

    resources :remote_control, :only => [:create, :update, :show]

    # Twitter direct interaction
    namespace :twitter do
      post 'follow/:twitter_user_name', :action => "follow"
    end

    # User related
    get 'user' => 'user#show'
    get 'signed_in' => 'user#signed_in'

    ########################
    # Javascript Error Reporting
    post 'js_err' => 'javascript_errors#create'

    #----------------------------------------------------------------
    # POST, PUT, DELETE aliases for JSONP :-[  b/c we support IE 8, 9
    #----------------------------------------------------------------
    # user
    get 'PUT/user/:id' => 'user#update'
      # user password reset is done outside of /v1
    # roll
    get 'POST/roll/:roll_id/share' => 'roll#share'
    get 'POST/roll/:roll_id/join' => 'roll#join'
    get 'POST/roll/:roll_id/leave' => 'roll#leave'
    get 'POST/roll' => 'roll#create'
    get 'PUT/roll/:id' => 'roll#update'
    get 'DELETE/roll/:id' => 'roll#destroy'
    # genius
    get 'POST/roll/genius' => 'genius#create'
    # frame
    get 'POST/roll/:roll_id/frames' => "frame#create"
    get 'POST/frame/:frame_id/upvote' => 'frame#upvote'
    get 'POST/frame/:frame_id/add_to_watch_later' => 'frame#add_to_watch_later'
    get 'PUT/frame/:frame_id/like' => 'frame#like'
    get 'POST/frame/:frame_id/watched' => 'frame#watched'
    get 'POST/frame/:frame_id/share' => 'frame#share'
    get 'DELETE/frame/:id' => 'frame#destroy'
    # video
    get 'PUT/video/:video_id/unplayable' => 'video#unplayable'
    # dashboard entry
    get 'PUT/dashboard/:id' => 'dashboard_entries#update'
    # messages
    get 'POST/conversation/:conversation_id/messages' => 'messages#create'
    get 'DELETE/conversation/:conversation_id/messages/:id' => 'messages#destroy'
    # discussion roll
    get 'POST/discussion_roll/:discussion_roll_id/messages' => 'discussion_roll#create_message'
    get 'POST/discussion_roll' => 'discussion_roll#create'
    # beta_invites
    get 'POST/beta_invite' => 'beta_invite#create'
    # gt_interest
    get 'POST/gt_interest/' => 'gt_interest#create'
    # twitter
    get 'POST/twitter/follow/:twitter_user_name' => 'twitter#follow'
    # js_error
    get 'POST/js_err' => 'javascript_errors#create'

  end

  get '/sign_out_user' => 'authentications#sign_out_user', :as => :sign_out_user

  resources :cohort_entrance, :only => [:show] do
    get '/popup' => "cohort_entrance#show_popup"
  end

  # constraints allows for nicknames that include dots, prevents changing format (we're json only, that's ok).
  get '/admin/user/:id' => 'admin#user', :constraints => { :id => /[^\/]+/ }
  get '/admin/user' => 'admin#user', :constraints => { :id => /[^\/]+/ }
  get '/admin/new_users' => "admin#new_users"
  get '/admin/active_users' => "admin#active_users"
  get '/admin/invited_users' => "admin#invited_users"

  # looking for web_root_url?  You should use Settings::ShelbyAPI.web_root

  root :to => redirect(Settings::ShelbyAPI.web_root)

end
