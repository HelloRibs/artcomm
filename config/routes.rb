Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/*
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest

  get  "signup", to: "registrations#new"
  post "signup", to: "registrations#create"

  get    "login",  to: "sessions#new"
  post   "login",  to: "sessions#create"
  delete "logout", to: "sessions#destroy"

  resource :account, only: %i[show update]

  namespace :dashboard do
    root "projects#index"

    resources :projects do
      member do
        post :move
      end

      resources :art_pieces, except: %i[index show] do
        member do
          post :move
        end
      end
    end
  end

  # Defines the root path route ("/")
  root "home#index"

  # Public artist pages. These sit at the root of the URL space so an artist's
  # gallery reads as their own address rather than a platform path, so they must
  # come last — every real route above wins first, and User::RESERVED_USERNAMES
  # keeps anyone from claiming one of them.
  # Unanchored on purpose: Rails rejects \A and \z in routing constraints, and
  # these must stay in step with User::USERNAME_FORMAT and Project::SLUG_FORMAT.
  slug_pattern = /[a-z0-9](?:[a-z0-9-]*[a-z0-9])?/

  scope constraints: { username: slug_pattern, id: slug_pattern } do
    get "/:username",     to: "artists#show",  as: :artist
    get "/:username/:id", to: "projects#show", as: :project
  end
end
