require "test_helper"

# Every roll you make shows as the same toast on the page you land on.
class RollToastTest < ActionDispatch::IntegrationTest
  setup do
    @campaign = campaigns(:bramblewood)
  end

  test "a story roll shows its toast back at the table, to the one who rolled it" do
    sign_in_as identities(:gwen)
    post campaign_story_rolls_path(@campaign), params: { question: "Is the bridge out?", odds: 2 }
    follow_redirect!

    assert_select "#roll-toast .roll-toast__title", /Story roll · just now$/
    assert_select ".toasts > #roll-toast", 1, "at the top of the toast stack"
    assert_select "#roll-toast .roll-toast__question", "Is the bridge out?"
    assert_select "#roll-toast .roll-result__word", 1

    sign_out
    sign_in_as identities(:pip)
    get campaign_path(@campaign)
    assert_select "#roll-toast", 0, "someone else's roll is in the log, not a toast"
  end

  test "a pool roll shows the dice and what's left" do
    sign_in_as identities(:pip)
    post campaign_pool_roll_path(@campaign, pools(:lookouts))
    follow_redirect!

    assert_select "#roll-toast .roll-toast__title", /Lookouts spot you · just now$/
    assert_select "#roll-toast .roll-toast__pool .die", 6
    assert_select "#roll-toast .roll-toast__setup", /left|0d/
  end

  test "it's gone 10 seconds on" do
    sign_in_as identities(:pip)
    post campaign_pool_roll_path(@campaign, pools(:lookouts))

    travel 11.seconds do
      get campaign_path(@campaign)
      assert_select "#roll-toast", 0
    end
  end
end
