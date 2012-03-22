ShelbyGt::Application.routes.draw do
  # The priority is based upon order of creation:
  # first created -> highest priority.

  
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
  # Namespace allows for versioning of API
  # NOTE: Must use V1::ControllerName in controllers
  namespace :v1, :defaults => { :format => 'json' } do
    resources :user, :only => [:show, :update] 
    resources :roll, :only => [:show, :create, :update, :destroy]
    resources :frame, :only => [:show, :destroy]
    resources :video, :only => [:show]
    resources :dashboard_entries, :path => "dashboard", :only => [:index, :update]
    resources :conversation, :only => [:show] do 
      resources :messages, :only => [:create, :destroy]
    end
    
    get 'user/' => 'user#show'
    get 'signed_in' => 'user#signed_in'
    post 'frame/:id/upvote' => 'frame#upvote'
    get 'roll/:id/frames' => 'frame#index'
    post 'roll/:id/frames' => 'frame#create'
    
  end
  
  get '/sign_out_user' => 'authentications#sign_out_user', :as => :sign_out_user
  
  root :to => 'authentications#index'

end
