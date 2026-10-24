require "test_helper"

class ErrorNotifierTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper

  setup do
    @was = ENV["ERROR_EMAIL_TO"]
    ENV["ERROR_EMAIL_TO"] = "gm@example.com"
    @notifier = ErrorNotifier.new(cache: ActiveSupport::Cache::MemoryStore.new)
  end

  teardown { ENV["ERROR_EMAIL_TO"] = @was }

  test "emails a failed job's error" do
    assert_enqueued_emails 1 do
      report Net::OpenTimeout.new("execution expired"), source: "application.solid_queue"
    end
  end

  test "the email names the error, where it came from and its backtrace" do
    error = RuntimeError.new("boom").tap { |e| e.set_backtrace([ "app/models/roll.rb:12:in 'story!'" ]) }
    perform_enqueued_jobs { report error }

    email = ActionMailer::Base.deliveries.last
    assert_equal [ "gm@example.com" ], email.to
    assert_equal "Grimwilder error: RuntimeError: boom", email.subject
    assert_match "From: application.action_dispatch", email.body.to_s
    assert_match "app/models/roll.rb:12", email.body.to_s
  end

  test "the same error is emailed once an hour, a different one straight away" do
    assert_enqueued_emails 2 do
      2.times { report Net::OpenTimeout.new("execution expired") }
      report RuntimeError.new("boom")
    end

    travel ErrorNotifier::QUIET_FOR + 1.minute do
      assert_enqueued_emails 1 do
        report Net::OpenTimeout.new("execution expired")
      end
    end
  end

  test "leaves out not-found and other client errors, and handled ones" do
    assert_no_enqueued_emails do
      report ActiveRecord::RecordNotFound.new("Couldn't find Campaign")
      report ActionController::RoutingError.new("No route matches [GET] \"/wp-login.php\"")
      report RuntimeError.new("rescued"), handled: true
    end
  end

  test "a failure while alerting doesn't escape" do
    broken_cache = Object.new.tap { |cache| def cache.write(*, **) = raise("cache database is down") }
    @notifier = ErrorNotifier.new(cache: broken_cache)

    assert_nothing_raised { report RuntimeError.new("boom") }
  end

  private
    def report(error, handled: false, source: "application.action_dispatch")
      @notifier.report(error, handled:, severity: handled ? :warning : :error, context: {}, source:)
    end
end
