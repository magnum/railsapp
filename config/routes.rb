Rails.application.routes.draw do
  mount MissionControl::Jobs::Engine, at: "/jobs"

  namespace :admin do
    resources :workspaces
    resources :bookmarks
    resources :menu_items
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
    resources :static_pages, param: :slug
    root to: "users#index"
  end
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  get "test/email", to: "test/emails#show", as: :test_email
  post "test/email", to: "test/emails#create"

  concern :apiable do
    get "test", to: "test#index"
    # resources :documents, only: [:index, :show, :create]
  end

  # Auth (outside locale scope — session drives I18n, like flycal)
  get "sign_in", to: "sessions#new", as: :sign_in
  post "sign_in", to: "sessions#create"
  get "sign_in/two_factor", to: "sessions#two_factor", as: :sign_in_two_factor
  post "sign_in/two_factor", to: "sessions#create_two_factor"
  post "sign_in/magic_link", to: "sessions#create_magic_link", as: :sign_in_magic_link
  get "sign_in/magic_link", to: "sessions#magic_link_prompt", as: :sign_in_magic_link_prompt
  post "sign_in/magic_link/code", to: "sessions#consume_magic_code", as: :sign_in_magic_code
  get "sign_in/magic_link/:token", to: "sessions#consume_magic_link", as: :consume_sign_in_magic_link
  delete "sign_out", to: "sessions#destroy", as: :sign_out

  post "select_workspace", to: "select_workspace#create"
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

  resources :users, only: [ :index, :show, :edit, :update ] do
    resource :two_factor, only: [ :create, :destroy ], controller: "users/two_factors" do
      post :confirm
      get :backup_codes
      delete :backup_codes, action: :dismiss_backup_codes
    end
  end
  post "bookmarks/toggle", to: "bookmarks#toggle", as: :toggle_bookmark

  namespace :api do
    concerns :apiable
    namespace :v1 do
      concerns :apiable
    end
  end

  resources :static_pages, param: :slug, constraints: { slug: /[a-z0-9]+(?:-[a-z0-9]+)*/ }, except: [ :show ]

  root "public#home"

  slug_constraint = /[a-z0-9]+(?:-[a-z0-9]+)*/
  get "/404", to: "static_pages#show", defaults: { slug: "404" }, as: :app_not_found
  scope "(:locale)", constraints: { locale: /#{Regexp.union(I18n.available_locales.map(&:to_s))}/ } do
    get "/:slug", to: "static_pages#show", as: :view_static_page,
        constraints: { slug: slug_constraint }
  end
end
