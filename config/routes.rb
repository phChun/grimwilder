Rails.application.routes.draw do
  root "pages#home"

  # Play toolkit (public)
  resource :roll, only: :show

  # Passwordless sign-in: emailed code or passkey
  resource :session, only: %i[ new create destroy ] do
    scope module: :sessions do
      resource :magic_link, only: %i[ show create ]
      resource :passkey_challenge, only: :create
      resource :passkey, only: :create
    end
  end

  resource :profile, only: %i[ show update ]

  namespace :passkeys do
    resource :challenge, only: :create
  end
  resources :passkeys, only: %i[ create destroy ]

  # Campaigns: the shared table a GM runs and players join
  resources :campaigns, except: %i[ new edit ] do
    scope module: :campaigns do
      resource :join_code, only: :update
      resources :memberships, only: :destroy
    end
  end

  get "join/:code", to: "joins#show", as: :join
  post "join/:code", to: "joins#create"

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  get "up" => "rails/health#show", as: :rails_health_check
end
