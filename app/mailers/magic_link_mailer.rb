class MagicLinkMailer < ApplicationMailer
  def sign_in_instructions(magic_link)
    @magic_link = magic_link
    mail to: magic_link.email_address, subject: "Your Grimwilder sign-in code: #{magic_link.code}"
  end
end
