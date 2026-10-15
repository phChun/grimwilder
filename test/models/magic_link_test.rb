require "test_helper"

class MagicLinkTest < ActiveSupport::TestCase
  test "generates a 6-character code that expires in 15 minutes" do
    link = MagicLink.create!(email_address: " Someone@Example.com ")

    assert_equal 6, link.code.length
    assert_equal "someone@example.com", link.email_address
    assert_in_delta 15.minutes.from_now, link.expires_at, 5.seconds
  end

  test "consume redeems once, for the matching email only" do
    link = MagicLink.create!(email_address: "someone@example.com")

    assert_nil MagicLink.consume(link.code, email_address: "other@example.com")
    assert MagicLink.consume(link.code.downcase, email_address: "SOMEONE@example.com")
    assert_nil MagicLink.consume(link.code, email_address: "someone@example.com")
  end

  test "consume ignores expired codes" do
    link = MagicLink.create!(email_address: "someone@example.com", expires_at: 1.minute.ago)

    assert_nil MagicLink.consume(link.code, email_address: "someone@example.com")
  end

  test "codes forgive letters that look like digits" do
    assert_equal "011", MagicLink::Code.sanitize("o-I l")
  end
end
