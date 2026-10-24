# Email production errors to ERROR_EMAIL_TO (config/deploy.yml). See ErrorNotifier.
Rails.application.config.after_initialize do
  Rails.error.subscribe(ErrorNotifier.new) if ErrorNotifier.recipient
end
