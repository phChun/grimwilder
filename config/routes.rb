Rails.application.routes.draw do
  # One canonical origin: passkeys and cookies are bound to grimwilder.com.
  constraints(host: "www.grimwilder.com") do
    match "(*path)", to: redirect { |_params, request| "https://grimwilder.com#{request.fullpath}" }, via: :all
  end

  root "pages#home"

  # Play toolkit (public)
  resource :roll, only: :show
  resources :crucibles, only: %i[ index show ]
  resources :talents, only: :index

  resources :characters do
    scope module: :characters do
      resources :rolls, only: :create do
        resource :critical_spark, only: :create, module: :rolls
      end
      resource :experience, only: :create
      resources :conditions, only: %i[ create destroy ] do
        resource :roll, only: :create, module: :conditions
      end
      resources :talents, only: %i[ new create destroy ]
      resource :talent_uses, only: :update
    end
  end

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
  resources :campaigns, except: :new do
    scope module: :campaigns do
      resource :join_code, only: :update
      resource :play, only: :show
      resource :table, only: :show
      resources :memberships, only: :destroy
      resources :story_rolls, only: :create
      resources :quarrels, only: %i[ new create ]
      resources :montages, only: %i[ new create ]

      resources :play_sessions, only: %i[ index show new create update ] do
        scope module: :play_sessions do
          resource :ending, only: %i[ new create ]
          resources :moments, only: :create
        end
      end
      resource :suspense, only: :update

      resources :scenes, only: %i[ new create update ] do
        resource :ending, only: %i[ new create ], module: :scenes
      end
      resources :notes, only: :create
      resources :messages, only: :create do
        resource :nomination, only: :create, module: :messages
      end
      resource :rest, only: :create
      resource :downtime, only: %i[ new create ]

      resources :pools, only: %i[ index create update destroy ] do
        scope module: :pools do
          resource :roll, only: :create
          resource :push, only: :create
          resource :reset, only: :create
        end
      end
    end
  end

  resources :pools, only: :index

  get "join/:code", to: "joins#show", as: :join
  post "join/:code", to: "joins#create"

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  get "up" => "rails/health#show", as: :rails_health_check
end
