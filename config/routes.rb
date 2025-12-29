Rails.application.routes.draw do
  root "card_sets#index"

  # Authentication routes
  get "sign_up", to: "registrations#new", as: "sign_up"
  post "sign_up", to: "registrations#create"
  get "login", to: "sessions#new", as: "login"
  post "login", to: "sessions#create"
  delete "logout", to: "sessions#destroy", as: "logout"

  resources :card_sets, only: [ :index, :show ] do
    post :download_set, on: :collection
    patch :update_card, on: :member
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
