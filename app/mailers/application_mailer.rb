class ApplicationMailer < ActionMailer::Base
  default from: -> { ENV.fetch("MAILER_FROM", "Grimwilder <no-reply@grimwilder.local>") }
  layout "mailer"
end
