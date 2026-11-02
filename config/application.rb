require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Grimwilder
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.2

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # Whether new people can make an account. ALLOW_SIGNUPS=false closes sign-ups:
    # existing accounts still sign in, and so can anyone holding a campaign's
    # invite link. See Identity.signups_open?.
    config.x.signups_open = ActiveModel::Type::Boolean.new.cast(ENV.fetch("ALLOW_SIGNUPS", "true"))

    # Which release is running, shown in /admin: the GitHub release's tag and
    # its commit, baked into the image when it's built (Dockerfile, config/deploy.yml).
    config.x.version = ENV["APP_VERSION"].presence
    config.x.revision = ENV["APP_REVISION"].presence

    # Nothing here transforms images, so there's no image_processing or libvips
    # (the production image has neither).
    config.active_storage.variant_processor = :disabled
  end
end
