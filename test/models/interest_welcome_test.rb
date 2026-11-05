require "test_helper"

class InterestWelcomeTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper

  test "an account for someone on the list sends a welcome, only once" do
    interest = Interest.record!(email_address: "ana@example.com")

    ana = nil
    assert_enqueued_emails 1 do
      ana = Identity.create!(email_address: "Ana@example.com", plan: "free")
    end
    assert_enqueued_email_with WelcomeMailer, :welcome, args: [ ana ]
    assert interest.reload.welcomed?

    assert_no_enqueued_emails do
      interest.welcome!
      Interest.welcome_all
    end
  end

  test "once per account, even if they're taken off the list and ask again" do
    Interest.record!(email_address: "ana@example.com")
    ana = Identity.create!(email_address: "ana@example.com")
    Interest.find_by!(email_address: "ana@example.com").destroy!

    travel 1.minute do
      assert_no_enqueued_emails do
        Interest.record!(email_address: "ana@example.com").welcome!
        Interest.welcome_all
      end
    end
  end

  test "an account for someone not on the list sends nothing" do
    assert_no_enqueued_emails { Identity.create!(email_address: "bo@example.com") }
  end

  test "welcome_all catches accounts made before there was a welcome" do
    interest = Interest.record!(email_address: "ana@example.com")
    Interest.where(id: interest).update_all(welcomed_at: nil, created_at: 2.days.ago)
    Identity.insert!({ email_address: "ana@example.com", plan: "free", created_at: 1.day.ago, updated_at: 1.day.ago })
    Interest.record!(email_address: "cy@example.com")

    assert_enqueued_emails 1 do
      Interest.welcome_all
    end
    assert interest.reload.welcomed?
    assert_no_enqueued_emails { Interest.welcome_all }
  end

  test "someone who already had an account and asked anyway isn't welcomed" do
    Interest.record!(email_address: identities(:gwen).email_address)
    assert_no_enqueued_emails { Interest.welcome_all }
  end

  test "the welcome says how to sign in" do
    email = WelcomeMailer.welcome(identities(:tess))
    assert_equal [ "tess@example.com" ], email.to
    assert_match "Tester plan", email.text_part.body.to_s
    assert_match "/session/new", email.text_part.body.to_s
  end
end
