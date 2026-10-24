# Emails ERROR_EMAIL_TO when something breaks in production: an exception a
# request didn't rescue, or a background job that failed (a sign-in code that
# couldn't be sent). A Rails.error subscriber (config/initializers/error_notifier.rb).
#
# Not-found and other 4xx errors are left out, since bots trigger them all day.
# The same error is emailed at most once per QUIET_FOR, which also stops a loop
# when the failure is email itself: the alert's own delivery fails the same way
# and is held back.
class ErrorNotifier
  QUIET_FOR = 1.hour

  def self.recipient
    ENV["ERROR_EMAIL_TO"].presence
  end

  def initialize(cache: Rails.cache)
    @cache = cache
  end

  def report(error, handled:, severity:, context:, source: nil)
    return if handled || client_error?(error) || !first_in_a_while?(error, source)

    ErrorMailer.report(
      error_class: error.class.name,
      message: error.message.to_s.truncate(1_000),
      backtrace: Array(error.backtrace).first(20),
      source: source.to_s,
      at: Time.current.iso8601
    ).deliver_later
  rescue => notify_error
    # Never let the alert take down whatever was reporting.
    Rails.logger.error("ErrorNotifier couldn't send an alert: #{notify_error.class}: #{notify_error.message}")
  end

  private
    def client_error?(error)
      ActionDispatch::ExceptionWrapper.status_code_for_exception(error.class.name) < 500
    end

    def first_in_a_while?(error, source)
      key = "error_notifier/#{Digest::SHA256.hexdigest([ error.class.name, error.message.to_s.first(200), source ].join("|"))}"
      @cache.write(key, true, expires_in: QUIET_FOR, unless_exist: true)
    end
end
