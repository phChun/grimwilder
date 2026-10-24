class ErrorMailer < ApplicationMailer
  # Plain strings only, so it survives deliver_later. See ErrorNotifier.
  def report(error_class:, message:, backtrace:, source:, at:)
    @error_class, @message, @backtrace, @source, @at = error_class, message, backtrace, source, at
    mail to: ErrorNotifier.recipient, subject: "Grimwilder error: #{error_class}: #{message.truncate(80)}"
  end
end
