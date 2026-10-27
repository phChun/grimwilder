require "test_helper"

class RollFollowUpsTest < ActionDispatch::IntegrationTest
  setup do
    @campaign = campaigns(:bramblewood)
    @tibbs, @bram = characters(:tibbs), characters(:bram)
  end

  test "the roll toast links to what your talents can do, and a follow-up changes the roll" do
    @tibbs.update!(talent_keys: [ "blessed" ])
    roll = @tibbs.roll!("agility", by: identities(:pip), random: FixedDice.new([ 1, 2, 3 ]))
    sign_in_as identities(:pip)

    get character_path(@tibbs)
    assert_select "#roll-toast a[href='#{new_campaign_roll_follow_up_path(@campaign, roll)}'][data-turbo-frame=modal]", text: "After the roll…"
    assert_select "#table_feed a[href='#{new_campaign_roll_follow_up_path(@campaign, roll)}']", text: "Talents after the roll"

    get new_campaign_roll_follow_up_path(@campaign, roll)
    assert_select "turbo-frame#modal h1", text: "After the roll"
    assert_select ".follow-ups__item", text: /Blessed.*Re-roll it without thorns/m

    post campaign_roll_follow_up_path(@campaign, roll), params: { character_id: @tibbs.id, follow_up: "blessed/reroll" }, headers: { "HTTP_REFERER" => character_url(@tibbs) }
    assert_redirected_to character_url(@tibbs)
    assert_equal "reroll", roll.reload.follow_ups.sole["kind"]

    get character_path(@tibbs)
    assert_select "#roll-toast .roll-toast__setup", text: /re-rolled it without thorns/
  end

  test "a player brings only their own characters; the GM brings anyone's" do
    @bram.update!(path: "Bard", talent_keys: [])
    roll = @tibbs.roll!("agility", by: identities(:pip), random: FixedDice.new([ 3, 2, 1 ]))

    sign_in_as identities(:pip)
    get new_campaign_roll_follow_up_path(@campaign, roll)
    assert_select ".field__hint", text: /None of your talents/
    post campaign_roll_follow_up_path(@campaign, roll), params: { character_id: @bram.id, follow_up: "inspiration/inspiration", die: 3 }
    assert_response :not_found

    sign_out
    sign_in_as identities(:gwen)
    get new_campaign_roll_follow_up_path(@campaign, roll)
    assert_select "form button", text: "3 → 4"
    post campaign_roll_follow_up_path(@campaign, roll), params: { character_id: @bram.id, follow_up: "inspiration/inspiration", die: 3 }
    assert_equal [ 4, 2, 1 ], roll.reload.dice
  end

  test "a follow-up that no longer fits says so" do
    roll = @tibbs.roll!("agility", by: identities(:pip), random: FixedDice.new([ 3, 2, 1 ]))
    sign_in_as identities(:pip)

    post campaign_roll_follow_up_path(@campaign, roll), params: { character_id: @tibbs.id, follow_up: "blessed/reroll" }
    assert_equal "That talent can't change this roll now.", flash[:alert]
  end
end
