require "active_support/core_ext/integer/time"

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # Code is not reloaded between requests.
  config.enable_reloading = false

  # Eager load code on boot for better performance and memory savings.
  config.eager_load = true

  # In Rake tasks, the previous assignment is ignored, config.eager_load is set
  # from config.rake_eager_load.
  config.rake_eager_load = false

  # Full error reports are disabled.
  config.consider_all_requests_local = false

  # Turn on fragment caching in view templates.
  config.action_controller.perform_caching = true

  # Cache assets for far-future expiry since they are all digest stamped.
  config.public_file_server.headers = { "cache-control" => "public, max-age=#{1.year.to_i}" }

  # Enable serving of images, stylesheets, and JavaScripts from an asset server.
  config.asset_host = ENV["CDN_HOST"]

  # Store uploaded files on the local file system (see config/storage.yml for options).
  config.active_storage.service = :local

  # Assume all access to the app is happening through a SSL-terminating reverse proxy.
  # kamal-proxy terminates SSL (Let's Encrypt) in front of the app.
  config.assume_ssl = true

  # Force all access to the app over SSL, use Strict-Transport-Security, and use secure cookies.
  config.force_ssl = true

  # Skip http-to-https redirect for the default health check endpoint.
  config.ssl_options = { redirect: { exclude: ->(request) { request.path == "/up" } } }

  # Log to STDOUT with the current request id as a default log tag.
  config.log_tags = [ :request_id ]
  config.logger   = ActiveSupport::TaggedLogging.logger(STDOUT)

  # Change to "debug" to log everything (including potentially personally-identifiable information!).
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")

  # Prevent health checks from clogging up the logs.
  config.silence_healthcheck_path = "/up"

  # Don't log any deprecations.
  config.active_support.report_deprecations = false

  # Replace the default file-based cache store with a more robust alternative.
  config.cache_store = :solid_cache_store

  # Replace the default in-process and non-durable queuing backend for Active Job.
  config.active_job.queue_adapter = :solid_queue
  config.solid_queue.connects_to = { database: { writing: :queue } }

  # Sign-in codes are emailed, so a failed delivery should show up (the job retries and logs it).
  config.action_mailer.raise_delivery_errors = true

  # Set host to be used by links generated in mailer templates.
  config.action_mailer.default_url_options = { host: "grimwilder.com", protocol: "https" }

  # Outgoing email: sign-in codes go out through Resend, with its SMTP details
  # in the credentials (`bin/rails credentials:edit`):
  #
  #   smtp:
  #     address: smtp.resend.com
  #     port: 2587
  #     user_name: resend
  #     password: re_...
  #
  # Port 2587, not 587: DigitalOcean blocks outgoing 25, 465 and 587 on the
  # droplet. Resend takes STARTTLS on 2587 too.
  if (smtp = Rails.application.credentials.smtp)
    config.action_mailer.delivery_method = :smtp
    config.action_mailer.smtp_settings = {
      address: smtp[:address],
      port: smtp.fetch(:port, 587),
      user_name: smtp[:user_name],
      password: smtp[:password],
      authentication: :plain,
      enable_starttls_auto: true
    }
  end

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation cannot be found).
  config.i18n.fallbacks = true

  # Do not dump schema after migrations.
  config.active_record.dump_schema_after_migration = false

  # Only use :id for inspections in production.
  config.active_record.attributes_for_inspect = [ :id ]

  # Enable DNS rebinding protection and other `Host` header attacks.
  # www redirects to the bare domain (config/routes.rb).
  config.hosts = [ "grimwilder.com", "www.grimwilder.com" ]

  # Skip DNS rebinding protection for the default health check endpoint.
  config.host_authorization = { exclude: ->(request) { request.path == "/up" } }
end
