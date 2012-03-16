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
  match '/auth/:provider/callback' => 'authentications#create'
  match '/auth/failure' => 'authentications#fail'


  ########################
  # Namespace allows for versioning of API
  # NOTE: Must use V1::ControllerName in controllers
  namespace :v1, :defaults => { :format => 'json', :constraints => {:method => 'OPTIONS'} } do
    resources :user, :only => [:show, :update] 
    resources :roll, :only => [:show, :create, :update, :destroy]
    resources :frame, :only => [:show, :destroy]
    resources :video, :only => [:show]
    resources :dashboard_entries, :path => "dashboard", :only => [:index, :update]
    resources :conversation, :only => [:show] do 
      resources :messages, :only => [:create, :destroy]
    end
    
    match 'user/' => 'user#show', :via => :get
    match 'frame/:id/upvote' => 'frame#upvote', :via => :post
    match 'roll/:id/frames' => 'frame#index', :via => :get
    match 'roll/:id/frames' => 'frame#create', :via => :post	
    
  end
  
  root :to => 'authentications#index'

end
