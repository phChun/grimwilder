require "test_helper"

class IdentityTest < ActiveSupport::TestCase
  test "email addresses are normalized and unique" do
    identity = Identity.create!(email_address: "  New@Example.COM ")
    assert_equal "new@example.com", identity.email_address

    assert_no_difference -> { Identity.count } do
      assert_equal identity, Identity.find_or_create_for_sign_in!("NEW@example.com")
    end
  end

  test "display name falls back to the email's local part" do
    assert_equal "someone", Identity.new(email_address: "someone@example.com").display_name
    assert_not Identity.new(email_address: "someone@example.com").profile_complete?
  end
end
