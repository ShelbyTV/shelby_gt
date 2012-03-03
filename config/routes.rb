ShelbyGt::Application.routes.draw do
  # The priority is based upon order of creation:
  # first created -> highest priority.

  
  ########################
  # Authentication and User Managment
  devise_for :users, :skip => [:sessions] do
    get 'signout' => 'devise/sessions#destroy', :as => :destroy_user_session
    get 'login' => 'home#index', :as => :new_user_session
  end

  resources :authentications
  match '/auth/:provider/callback' => 'authentications#create'
  match '/auth/failure' => 'authentications#fail'
  

  ########################
  # Allows for versioning of API
  # NOTE: Must use V1::ControllerName in controllers
  namespace :v1 do
    resources :user, :roll, :frame, :video, :dashboard_entries
    resources :conversation do 
      resources :message
    end
  end

  # Sample of regular route:
  #   match 'products/:id' => 'catalog#view'
  # Keep in mind you can assign values other than :controller and :action

  root :to => 'home#index'

end
