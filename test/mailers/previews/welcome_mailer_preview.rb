# /rails/mailers/welcome_mailer/welcome in development.
class WelcomeMailerPreview < ActionMailer::Preview
  def welcome
    WelcomeMailer.welcome(Identity.new(email_address: "ana@example.com", plan: Identity.column_defaults["plan"]))
  end
end
