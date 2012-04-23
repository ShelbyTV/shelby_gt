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
    resources :user, :only => [:show, :update] do
      get 'rolls' => 'user#rolls', :on => :member
      get 'personal_roll' => 'roll#show', :defaults => {:public_roll => true}
      get 'personal_roll/frames' => 'frame#index', :defaults => {:public_roll => true}
    end
    resources :roll, :only => [:show, :create, :update, :destroy] do
      get 'frames' => 'frame#index'
      get 'new_frame' => 'frame#create' #NOTE: this is for jsonp, cross domain requests made by video radar
      post 'frames' => 'frame#create'
      post 'share' => 'roll#share'
      post 'join' => 'roll#join'
      post 'leave' => 'roll#leave'
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
  end
  
  get '/sign_out_user' => 'authentications#sign_out_user', :as => :sign_out_user
  
  root :to => 'authentications#index'

end
