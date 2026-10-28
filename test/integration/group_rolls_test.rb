require "test_helper"

# Story rolls, quarrels and montages are called by the GM from the Rolls fold,
# then each player rolls their own dice in the roll call modal (or the GM
# rolls for them).
class GroupRollsTest < ActionDispatch::IntegrationTest
  setup do
    @campaign = campaigns(:bramblewood)
    @tibbs, @bram = characters(:tibbs), characters(:bram)
  end

  test "the GM calls a story roll for a character, and their player rolls it in the modal with spark" do
    sign_in_as identities(:gwen)
    get campaign_table_path(@campaign)
    assert_select "#rolls input[name=spark]", 0, "spark is picked when rolling"

    assert_no_difference -> { @campaign.rolls.story.count } do
      post campaign_story_rolls_path(@campaign), params: { question: "Is the bridge out?", odds: 1, character_id: @tibbs.id }
    end
    assert_redirected_to campaign_table_path(@campaign, anchor: "rolls")
    call = @campaign.roll_calls.open.sole

    sign_out
    sign_in_as identities(:pip)
    get campaign_path(@campaign)
    frame = "#roll_call_campaign_#{@campaign.id}"
    assert_select "#{frame} dialog .roll-call__title", "Story roll"
    assert_select "#{frame} .roll-call__question", "Is the bridge out?"
    assert_select "#{frame} form[action=?] input[name=spark][value='1']", campaign_roll_call_rolls_path(@campaign)
    assert_select "#{frame} form button[type=submit]", "Roll 1d"

    assert_difference -> { @campaign.rolls.story.count }, 1 do
      post campaign_roll_call_rolls_path(@campaign), params: { roll_call_id: call.id, character_id: @tibbs.id, spark: 1 }
    end
    assert_redirected_to campaign_roll_call_path(@campaign)
    roll = @campaign.rolls.story.last
    assert_equal 2, roll.dice.size, "1d for bad odds, plus 1 spark"
    assert_equal 1, roll.spark_spent
    assert_equal roll, call.reload.roll
    assert call.done?

    follow_redirect!
    assert_select "turbo-frame#{frame} .roll-call__result .roll-result__word", 1

    get campaign_path(@campaign)
    assert_select "#{frame} .roll-call__result", 1, "the result shows for a little while"
    assert_select "#roll-toast", 0, "not twice: no toast as well"
  end

  test "only the GM calls for rolls, on anyone at the table" do
    sign_in_as identities(:pip)
    post campaign_story_rolls_path(@campaign), params: { character_id: @tibbs.id }
    assert_response :forbidden
    post campaign_montages_path(@campaign), params: { participants: { @tibbs.id => { in: "1" } } }
    assert_response :forbidden
    post campaign_quarrels_path(@campaign), params: { participants: { @tibbs.id => { role: "quarrel" }, @bram.id => { role: "quarrel" } } }
    assert_response :forbidden
    assert_empty @campaign.roll_calls

    sign_out
    sign_in_as identities(:gwen)
    get campaign_table_path(@campaign)
    assert_select "#story_character option", 3, "no one, Tibbs or Bram"

    post campaign_story_rolls_path(@campaign), params: { character_id: @tibbs.id, thorns: 1 }
    assert_redirected_to campaign_table_path(@campaign, anchor: "rolls")
    follow_redirect!
    assert_select ".roll-call__seat form[action=?] button", campaign_roll_call_rolls_path(@campaign), text: "Roll for them"

    sign_out
    sign_in_as identities(:pip)
    get campaign_path(@campaign)
    assert_select ".roll-call__seat form button[type=submit]", "Roll 2d vs 1t"
  end

  test "a story roll for no one in particular is rolled straight away" do
    sign_in_as identities(:gwen)

    assert_difference -> { @campaign.rolls.story.count }, 1 do
      post campaign_story_rolls_path(@campaign), params: { question: "Does it rain?" }
    end
    assert_redirected_to campaign_table_path(@campaign, anchor: "roll-log")
    assert_empty @campaign.roll_calls
  end

  test "a bad story roll goes back with the reason" do
    sign_in_as identities(:gwen)

    post campaign_story_rolls_path(@campaign), params: { odds: 5 }
    assert_redirected_to campaign_table_path(@campaign, anchor: "rolls")
    assert_equal "Pick 1d, 2d or 3d for the odds.", flash[:alert]
  end

  test "settle a quarrel: each player rolls their own side" do
    sign_in_as identities(:gwen)

    get new_campaign_quarrel_path(@campaign)
    assert_select "select[name=?]", "participants[#{@tibbs.id}][role]"
    assert_select "select[name$='[spark]']", 0, "spark is picked when rolling"

    post campaign_quarrels_path(@campaign), params: { stakes: "Who keeps the map?", participants: {
      @tibbs.id => { role: "quarrel" }, @bram.id => { role: "quarrel" }
    } }
    assert_redirected_to campaign_table_path(@campaign, anchor: "rolls")
    call = @campaign.roll_calls.open.sole

    sign_out
    sign_in_as identities(:pip)
    get campaign_path(@campaign)
    assert_select ".roll-call__seat", 2
    assert_select ".roll-call__seat form", 1, "only Tibbs is Pip's to roll"
    assert_select ".roll-call__waiting", "Waiting to roll"

    post campaign_roll_call_rolls_path(@campaign), params: { roll_call_id: call.id, character_id: @tibbs.id, spark: 1 }
    assert_equal 0, @tibbs.reload.spark, "spent as Tibbs rolled"
    assert_equal 0, @campaign.rolls.quarrel.count, "still waiting on Bram"

    post campaign_roll_call_rolls_path(@campaign), params: { roll_call_id: call.id, character_id: @bram.id }
    assert_response :unprocessable_entity
    assert_select ".roll-call__error", "Only Bram's player or the GM can roll for them."

    sign_out
    sign_in_as identities(:gwen)
    assert_difference -> { @campaign.rolls.quarrel.count }, 1 do
      post campaign_roll_call_rolls_path(@campaign), params: { roll_call_id: call.id, character_id: @bram.id }
    end

    quarrel = @campaign.rolls.quarrel.last
    assert_equal "Who keeps the map?", quarrel.question
    assert_equal({ @tibbs.name => 3, "Bram" => 2 }, quarrel.sides.to_h { [ _1["name"], _1["dice"].size ] })
    assert_equal 1, @tibbs.reload.spark, "spent 1, then took 1"

    get campaign_table_path(@campaign)
    assert_select "#table_feed .feed-item__question", "Stakes: Who keeps the map?"
    assert_select "#table_feed .feed-item__meta", /Bram already holds 2/
  end

  test "the GM can roll for a player, but can't spend their spark" do
    call = RollCall.montage!(campaign: @campaign, by: identities(:pip), characters: [ @tibbs ])
    sign_in_as identities(:gwen)

    post campaign_roll_call_rolls_path(@campaign), params: { roll_call_id: call.id, character_id: @tibbs.id, spark: 1 }
    assert_response :unprocessable_entity
    assert_select ".roll-call__error", "Only #{@tibbs.name}'s player can spend their spark."

    post campaign_roll_call_rolls_path(@campaign), params: { roll_call_id: call.id, character_id: @tibbs.id }
    assert call.reload.done?
    assert_equal identities(:gwen).display_name, call.seats.first["rolled_by"]
  end

  test "an assist must back someone who's quarreling" do
    sign_in_as identities(:gwen)

    post campaign_quarrels_path(@campaign), params: { participants: {
      @tibbs.id => { role: "quarrel" }, @bram.id => { role: "assist-#{@tibbs.id}" }
    } }
    assert_response :unprocessable_entity
    assert_select ".toast__message", "A quarrel needs at least two sides."
  end

  test "outsiders can't quarrel or roll here" do
    sign_in_as identities(:stranger)

    get new_campaign_quarrel_path(@campaign)
    assert_response :not_found
    post campaign_story_rolls_path(@campaign)
    assert_response :not_found
    get campaign_roll_call_path(@campaign)
    assert_response :not_found
  end

  test "call a montage, and the GM rolls for everyone left" do
    sign_in_as identities(:gwen)
    get campaign_table_path(@campaign)
    assert_select "#rolls form[action=?]", campaign_montages_path(@campaign)

    get new_campaign_montage_path(@campaign)
    assert_select "input[type=checkbox]", 2

    post campaign_montages_path(@campaign), params: { scene: "The climb", participants: { @tibbs.id => { in: "1" }, @bram.id => { in: "1" } } }
    assert_redirected_to campaign_table_path(@campaign, anchor: "rolls")
    call = @campaign.roll_calls.open.sole

    sign_out
    sign_in_as identities(:pip)
    post campaign_roll_call_rolls_path(@campaign), params: { roll_call_id: call.id, character_id: @tibbs.id, spark: 1 }

    sign_out
    sign_in_as identities(:gwen)
    get campaign_table_path(@campaign)
    assert_select ".roll-call__seat--rolled", 1
    assert_select ".roll-call__actions button", { text: "Roll for everyone left", count: 0 }, "only Bram is left, so his own button will do"

    assert_difference -> { @campaign.rolls.montage.count }, 1 do
      post campaign_roll_call_rolls_path(@campaign), params: { roll_call_id: call.id, everyone: 1 }
    end
    assert_equal({ @tibbs.name => 3, "Bram" => 2 }, @campaign.rolls.montage.last.sides.to_h { [ _1["name"], _1["dice"].size ] })

    get campaign_table_path(@campaign)
    assert_select "#table_feed .feed-item__question", "The climb"
    assert_select "#table_feed .feed-item__meta", /highest result is the scene's outcome/
  end

  test "a montage needs someone in it" do
    sign_in_as identities(:gwen)

    post campaign_montages_path(@campaign), params: { participants: { @tibbs.id => { in: "0" } } }
    assert_select ".toast__message", "Pick who takes part in the montage."
    assert_empty @campaign.roll_calls
  end

  test "one call at a time, and calling it off gives spark back" do
    sign_in_as identities(:gwen)
    post campaign_montages_path(@campaign), params: { participants: { @tibbs.id => { in: "1" }, @bram.id => { in: "1" } } }
    call = @campaign.roll_calls.open.sole

    post campaign_quarrels_path(@campaign), params: { participants: { @tibbs.id => { role: "quarrel" }, @bram.id => { role: "quarrel" } } }
    assert_select ".toast__message", "Finish or cancel the montage that's waiting first."

    sign_out
    sign_in_as identities(:pip)
    post campaign_roll_call_rolls_path(@campaign), params: { roll_call_id: call.id, character_id: @tibbs.id, spark: 1 }
    assert_equal 0, @tibbs.reload.spark

    sign_out
    sign_in_as identities(:gwen)

    delete campaign_roll_call_path(@campaign), params: { roll_call_id: call.id }
    assert_redirected_to campaign_roll_call_path(@campaign)
    assert call.reload.cancelled?
    assert_equal 1, @tibbs.reload.spark
    assert_empty @campaign.rolls.montage

    follow_redirect!
    assert_select ".roll-call", 0
  end

  test "montage and quarrel are greyed out, saying why, until the party has the characters" do
    @campaign.characters.update_all(up_for_grabs: true)
    sign_in_as identities(:gwen)
    get campaign_table_path(@campaign)

    assert_select "#rolls .rolls__kinds input[name=roll_kind]", 3
    assert_select "#rolls .rolls__kinds label[title=?] input[value=montage][disabled]", "Needs a character at the table"
    assert_select "#rolls .rolls__kinds label[title=?] input[value=quarrel][disabled]", "Needs two characters at the table"
    assert_select "#rolls .rolls__kinds label:not([title]) input[value=story]:not([disabled])"
    assert_select "#rolls .rolls__needs", /Montages need a character in the party, and quarrels two/
  end
end
