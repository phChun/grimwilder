# The welcome for someone from the interest list once they have an account
# (Interest#welcome!), in the night-table look (layouts/night_mailer).
class WelcomeMailer < ApplicationMailer
  layout "night_mailer"

  def welcome(identity)
    @identity = identity
    mail to: identity.email_address, subject: "Your Grimwilder account is ready"
  end
end
