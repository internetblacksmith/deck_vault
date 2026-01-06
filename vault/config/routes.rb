Rails.application.routes.draw do
  root "card_sets#index"

  # API v1 endpoints (for MCP server and chat)
  namespace :api do
    namespace :v1 do
      get "stats", to: "stats#index"
      resources :sets, only: [ :index, :show ] do
        collection do
          post :download
        end
      end
      resources :cards, only: [ :index, :show, :update ]
    end
  end

  # Authentication routes
  get "sign_up", to: "registrations#new", as: "sign_up"
  post "sign_up", to: "registrations#create"
  get "login", to: "sessions#new", as: "login"
  post "login", to: "sessions#create"
  delete "logout", to: "sessions#destroy", as: "logout"

  # Chat with Claude
  get "chat", to: "chat#index"
  post "chat", to: "chat#create"

  # Settings
  get "settings", to: "settings#index", as: :settings
  patch "settings", to: "settings#update"
  delete "settings/clear_gist_id", to: "settings#clear_gist_id", as: :clear_gist_id_settings

  resources :card_sets, only: [ :index, :show, :destroy ] do
    collection do
      post :download_set
      get :available_sets
      get :export_collection
      post :import_collection
      post :import_delver
      post :import_delver_csv
      get :export_showcase
      get :export_duplicates
      post :publish_to_gist
    end
    member do
      patch :update_card
      post :retry_images
      post :refresh_cards
      patch :update_binder_settings
      post :import_csv
    end
  end

  # Serve card images
  get "card_images/:filename", to: "images#show", constraints: { filename: /[^\/]+\.jpg/ }

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
end
