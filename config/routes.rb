ShelbyGt::Application.routes.draw do
  # The priority is based upon order of creation:
  # first created -> highest priority.

  ########################
  # Namespace allows for versioning of API
  # NOTE: Must use V1::ControllerName in controllers
  namespace :v1 do
    resources :user, :only => [:show, :update] 
    resources :roll, :only => [:show, :create, :update, :destroy]
    resources :frame, :only => [:show, :update, :destroy]
    resources :video, :only => [:show]
    resources :dashboard_entries, :path => "dashboard", :only => [:index, :update]
    resources :conversation, :only => [:show] do 
      resources :messages, :only => [:create, :destroy]
    end
    
    match 'roll/:id/frames' => 'frame#index', :via => :get
    match 'roll/:id/frames' => 'frame#create', :via => :post	
    
  end
  

  root :to => 'home#index'

end
