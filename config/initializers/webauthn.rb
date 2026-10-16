# Passkeys (WebAuthn). APP_ORIGIN must match window.location.origin exactly,
# scheme and port included; set it in production (config/deploy.yml env).
# Passkeys are bound to the origin's host (the relying party id), so moving
# to a new domain later strands existing passkeys (email codes still work).
WebAuthn.configure do |config|
  default_origin = {
    "development" => "http://localhost:3000",
    "test" => "http://www.example.com"
  }.fetch(Rails.env, "https://grimwilder.com")

  origin = ENV.fetch("APP_ORIGIN", default_origin)

  config.allowed_origins = [ origin ]
  config.rp_id = URI.parse(origin).host
  config.rp_name = "Grimwilder"
  config.encoding = :base64url
end
