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
      get 'rolls' => 'user#roll_followings', :on => :member
      get 'roll_followings' => 'user#roll_followings', :on => :member
      get 'personal_roll' => 'roll#show', :defaults => {:public_roll => true}
      get 'personal_roll/frames' => 'frame#index', :defaults => {:public_roll => true}
    end
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
    resources :video, :only => [:show]
    resources :dashboard_entries, :path => "dashboard", :only => [:index, :update]
    resources :conversation, :only => [:show] do 
      resources :messages, :only => [:create, :destroy]
    end
    
    resources :gt_interest, :only => [:create]
    
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
  get '/web_root' => redirect('http://gt.shelby.tv'), :as => :web_root
  
  root :to => 'authentications#index'

end
