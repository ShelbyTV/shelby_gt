ShelbyGt::Application.routes.draw do
  # The priority is based upon order of creation:
  # first created -> highest priority.

  #for blitz.io
  #get '/mu-4a3bea60-210d9ed2-38279c19-649e9064' => 'home#verification'

  ########################
  # Authentication and User Managment

  devise_for :user, :skip => [:sessions]
  as :user do
    get 'signout' => 'devise/sessions#destroy', :as => :destroy_user_session
    get 'login' => 'authentications#index', :as => :new_user_session
  end

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

  resources :authentications
  get '/auth/:provider/callback' => 'authentications#create'
  get '/auth/failure' => 'authentications#fail'

  ########################
  # Video Radar / Bookmarklet
  get '/radar/boot' => 'video_radar#boot', :format => 'js'
  get '/radar/load' => 'video_radar#load', :format => 'js'

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
    
    resources :user, :only => [:show, :update] do
      get 'valid_token' => 'user#valid_token', :on => :member
      get 'rolls/following' => 'user#roll_followings', :on => :member
      get 'rolls/postable' => 'user#roll_followings', :on => :member, :defaults => { :postable => true }
      get 'rolls/personal' => 'roll#show_users_public_roll'
      get 'rolls/personal/frames' => 'frame#index_for_users_public_roll'
      get 'rolls/hearted' => 'roll#show_users_heart_roll'
      get 'rolls/heart/frames' => 'frame#index_for_users_heart_roll'
    end
    get 'roll/browse' => 'roll#browse'
    resources :roll, :only => [:show, :create, :update, :destroy] do
      get 'frames' => 'frame#index'
      post 'frames' => 'frame#create'
      post 'share' => 'roll#share'
      post 'join' => 'roll#join'
      post 'leave' => 'roll#leave'
    end
    namespace :roll do
       resources :genius, :only => [:create]
    end
    resources :frame, :only => [:show, :destroy] do
      post 'upvote' => 'frame#upvote'
      post 'add_to_watch_later' => 'frame#add_to_watch_later'
      post 'watched' => 'frame#watched'
      post 'share' => 'frame#share'
    end
    resources :video, :only => [:show] do
      get 'find', :on => :collection
      get 'conversations' => 'conversation#index'
    end
    resources :dashboard_entries, :path => "dashboard", :only => [:index, :update] do
      get 'find_entries_with_video' => 'dashboard_entries#find_entries_with_video', :on => :collection
    end
    resources :conversation, :only => [:show] do 
      resources :messages, :only => [:create, :destroy]
    end
    
    resources :gt_interest, :only => [:create]
    
    resources :token, :only => [:create, :destroy]
    
    # User related
    get 'user' => 'user#show'
    get 'signed_in' => 'user#signed_in'
    
    #----------------------------------------------------------------
    # POST, PUT, DELETE aliases for JSONP :-[  b/c we support IE 8, 9
    #----------------------------------------------------------------
    # user
    get 'PUT/user/:id' => 'user#update'
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
    get 'POST/frame/:frame_id/watched' => 'frame#watched'
    get 'POST/frame/:frame_id/share' => 'frame#share'
    get 'DELETE/frame/:id' => 'frame#destroy'
    # dashboard entry
    get 'PUT/dashboard/:id' => 'dashboard_entries#update'
    # messages
    get 'POST/conversation/:conversation_id/messages' => 'messages#create'
    get 'DELETE/conversation/:conversation_id/messages/:id' => 'messages#destroy'

  end
  
  get '/sign_out_user' => 'authentications#sign_out_user', :as => :sign_out_user
  get '/web_root' => redirect {|params,request| "http://gt.shelby.tv#{'?' + request.env["QUERY_STRING"] if request.env["QUERY_STRING"].length > 0}"}, :as => :web_root
  
  root :to => 'authentications#index'

end
