ShelbyGt::Application.routes.draw do
  # The priority is based upon order of creation:
  # first created -> highest priority.

  ########################
  # Allows for versioning of API
  # NOTE: Must use V1::ControllerName in controllers
  namespace :v1 do
    resources :users
    resources :rolls
    resources :frames
    resources :conversation
    resources :messages
    resources :videos
    resources :dashboard_entries
  end

  # Sample of regular route:
  #   match 'products/:id' => 'catalog#view'
  # Keep in mind you can assign values other than :controller and :action

  # root :to => 'welcome#index'

end
