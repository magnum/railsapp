Rails.application.routes.draw do
  mount MissionControl::Jobs::Engine, at: "/jobs"

  namespace :admin do
    resources :users
    resources :roles
    resources :plan_types
    resources :plans
    resources :invitations do
      member do
        put "/event/:event", to: "invitations#event", as: :event
      end
    end
    root to: "users#index"
  end
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Invitation consume: GET /invitations/consume or GET /invitations/consume/:code (pre-filled)
  get "invitations/consume", to: "invitations#consume", as: :invitation_consume
  get "invitations/consume/:code", to: "invitations#consume", as: :invitation_consume_with_code
  post "invitations/consume", to: "invitations#consume"

  # Authentication
  get "sign_in", to: "sessions#new", as: :sign_in
  post "sign_in", to: "sessions#create"
  delete "sign_out", to: "sessions#destroy", as: :sign_out
  get "auth/failure", to: "sessions#failure"
  get "auth/:provider/callback", to: "sessions#create"

  get "sign_up", to: "registrations#new", as: :sign_up
  post "sign_up", to: "registrations#create"

  get "set_session_locale/:locale", to: "locale#set_session_locale", as: :set_session_locale

  root "home#index"
end
