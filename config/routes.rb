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
      resource :damage, only: :update
      resource :vex, only: %i[ create destroy ]
      resources :conditions, only: %i[ create destroy ] do
        resource :roll, only: :create, module: :conditions
      end
      resource :talent_list, only: :update
      resources :talents, only: %i[ new create destroy ] do
        resource :skin, only: %i[ update destroy ], controller: "talent_skins"
        resource :choices, only: %i[ edit update ], controller: "talent_choices"
        resource :roll, only: :create, controller: "talent_rolls"
        resource :push, only: :create, controller: "talent_pushes"
        resources :made_pools, only: :create, controller: "talent_made_pools"
        resource :state, only: :update, controller: "talent_states"
      end
      resource :talent_uses, only: :update
      resources :arcana, only: %i[ new create edit update destroy ] do
        resource :use, only: %i[ create destroy ], controller: "arcana_uses"
        resource :opus, only: %i[ create update ], controller: "magnum_opuses"
      end
      resource :claim, only: %i[ create destroy ]
      resource :seat, only: :update
      resource :story_end, only: %i[ create destroy ]
      resource :stat_progression, only: %i[ create destroy ]
      resource :stat_point, only: :create
      resource :oath, only: %i[ create destroy ]
      resource :coins, only: :create
      resource :plan_thread, only: :destroy
      resources :goals, only: :destroy
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

  # Admins only (identities.admin): site stats, accounts and their plans, campaigns
  namespace :admin do
    root "dashboards#show"
    resources :identities, only: %i[ index create update ], path: "accounts"
    resources :campaigns, only: :index
    resources :interests, only: %i[ index destroy ] do
      resource :account, only: :create, module: :interests
    end
  end

  get "sitemap.xml", to: "sitemaps#show", as: :sitemap, defaults: { format: "xml" }

  # "I'm interested", while sign-ups are closed: the form, then thanks.
  resource :interest, only: %i[ new create show ]

  namespace :passkeys do
    resource :challenge, only: :create
  end
  resources :passkeys, only: %i[ create destroy ]

  # Campaigns: the shared table a GM runs and players join
  resources :campaigns, except: :new do
    scope module: :campaigns do
      resource :join_code, only: :update
      resource :join_link, only: %i[ create destroy ] # the GM turns the invite link on or off
      resource :play, only: :show
      resource :table, only: :show
      resources :memberships, only: :destroy
      resources :blocks, only: %i[ create destroy ] # the GM keeps someone out (Campaign::Blocking)
      resources :story_rolls, only: :create
      resource :feed, only: :show # older lines for the table rail, as you scroll back
      resources :quarrels, only: %i[ new create ]
      resources :montages, only: %i[ new create ]
      # The story roll, montage or quarrel waiting on its players (RollCall)
      resource :roll_call, only: %i[ show destroy ] do
        resources :rolls, only: :create, module: :roll_calls
      end
      # Talents that change a roll after it's made (Roll::FollowUps)
      resources :rolls, only: [] do
        resource :follow_up, only: %i[ new create ], module: :rolls
      end

      resources :play_sessions, only: %i[ index show new create update ] do
        scope module: :play_sessions do
          resource :ending, only: %i[ new create ]
        end
      end
      resource :suspense, only: :update

      resources :scene_plans, only: %i[ index create edit update destroy ]
      resources :scenes, only: %i[ new create update ] do
        resource :ending, only: %i[ new create ], module: :scenes
      end
      resources :messages, only: %i[ create destroy ]
      resource :rest, only: :create
      resource :rest_reset, only: %i[ new create ]
      resource :milestone, only: :create
      resource :archive, only: %i[ create destroy ] # the GM archives the campaign, or unarchives it
      resource :hold, only: :destroy # "Play this one": the GM lifts their plan hold, holding another if need be
      resource :schedule, only: :update # Settings › Schedule
      resources :game_dates, only: %i[ create update destroy ] # a rule date by its date (2026-11-07), an extra by id
      resource :reset, only: :create # the GM clears sessions and the roll log
      resource :downtime, only: %i[ new create ]
      resource :brief, only: :show

      resources :pools, only: %i[ index create update destroy ] do
        scope module: :pools do
          resource :roll, only: :create
          resource :push, only: :create
          resource :smite, only: :create
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
