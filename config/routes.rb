Rails.application.routes.draw do
  mount MissionControl::Jobs::Engine, at: "/jobs"

  namespace :admin do
    resources :users
    resources :roles
    resources :api_keys
    resources :plan_types
    resources :plans
    resources :invitations do
      member do
        put "/event/:event", to: "invitations#event", as: :event
      end
    end
    resources :webhooks do
      member do
        put "/event/:event", to: "webhooks#event", as: :event
      end
    end
    root to: "users#index"
  end
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  concern :apiable do
    get "test", to: "test#index"
    # resources :documents, only: [:index, :show, :create]
  end

  # Auth (outside locale scope — session drives I18n, like flycal)
  get "sign_in", to: "sessions#new", as: :sign_in
  post "sign_in", to: "sessions#create"
  delete "sign_out", to: "sessions#destroy", as: :sign_out
  get "auth/failure", to: "sessions#failure"
  get "auth/:provider/callback", to: "sessions#create"

  get "sign_up", to: "registrations#new", as: :sign_up
  post "sign_up", to: "registrations#create"

  resource :locale, only: [], controller: "locale" do
    get :update, on: :collection, as: :set_session
  end

  get "invitations/consume", to: "invitations#consume", as: :invitation_consume
  get "invitations/consume/:code", to: "invitations#consume", as: :invitation_consume_with_code
  post "invitations/consume", to: "invitations#consume"

  resources :users, only: [ :index, :show, :edit, :update ]

  namespace :api do
    concerns :apiable
    namespace :v1 do
      concerns :apiable
    end
  end

  root "public#home"

  slug_constraint = /[a-z0-9]+(?:-[a-z0-9]+)*/
  scope "(:locale)", constraints: { locale: /#{Regexp.union(I18n.available_locales.map(&:to_s))}/ } do
    get "/:slug", to: "static_pages#show", as: :static_page,
        constraints: { slug: slug_constraint }
  end
end
