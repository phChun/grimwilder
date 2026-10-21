require "test_helper"

class GroupRollsTest < ActionDispatch::IntegrationTest
  setup do
    @campaign = campaigns(:bramblewood)
    @tibbs, @bram = characters(:tibbs), characters(:bram)
  end

  test "make a story roll from the campaign page" do
    sign_in_as identities(:pip)
    get campaign_path(@campaign)
    assert_select "#story_character option", 2, "no one, or Tibbs"

    assert_difference -> { @campaign.rolls.story.count }, 1 do
      post campaign_story_rolls_path(@campaign), params: { question: "Is the bridge out?", odds: 1, character_id: @tibbs.id, spark: 1 }
    end
    assert_redirected_to campaign_path(@campaign, anchor: "roll-log")
    assert_equal 2, @campaign.rolls.story.last.dice.size

    follow_redirect!
    assert_select "#table_feed .feed-item__question", "Is the bridge out?"
    assert_select "#table_feed .feed-item__meta", /1d \(bad odds\) \+ 1 spark/
  end

  test "a story roll can't be for someone else's character" do
    sign_in_as identities(:pip)

    post campaign_story_rolls_path(@campaign), params: { character_id: @bram.id }
    assert_response :not_found
  end

  test "a bad story roll goes back with the reason" do
    sign_in_as identities(:gwen)

    post campaign_story_rolls_path(@campaign), params: { odds: 5 }
    assert_redirected_to campaign_table_path(@campaign, anchor: "story-roll")
    assert_equal "Pick 1d, 2d or 3d for the odds.", flash[:alert]
  end

  test "settle a quarrel" do
    sign_in_as identities(:pip)

    get new_campaign_quarrel_path(@campaign)
    assert_select "select[name=?]", "participants[#{@tibbs.id}][spark]"
    assert_select "select[name=?]", "participants[#{@bram.id}][spark]", { count: 0 }, "only your own spark"

    assert_difference -> { @campaign.rolls.quarrel.count }, 1 do
      post campaign_quarrels_path(@campaign), params: { stakes: "Who keeps the map?", participants: {
        @tibbs.id => { role: "quarrel", spark: 1 }, @bram.id => { role: "quarrel" }
      } }
    end
    assert_redirected_to campaign_path(@campaign, anchor: "roll-log")

    quarrel = @campaign.rolls.quarrel.last
    assert_equal({ @tibbs.name => 3, "Bram" => 2 }, quarrel.sides.to_h { [ _1["name"], _1["dice"].size ] })
    assert_equal 1, @tibbs.reload.spark, "spent 1, then took 1"

    follow_redirect!
    assert_select "#table_feed .feed-item__question", "Stakes: Who keeps the map?"
    assert_select "#table_feed .feed-item__meta", /Bram already holds 2/
  end

  test "you can't spend someone else's spark in a quarrel" do
    sign_in_as identities(:pip)

    assert_no_difference -> { Roll.count } do
      post campaign_quarrels_path(@campaign), params: { participants: {
        @tibbs.id => { role: "quarrel" }, @bram.id => { role: "quarrel", spark: 1 }
      } }
    end
    assert_response :unprocessable_entity
    assert_select ".toast__message", "Only Bram's player can spend their spark."
  end

  test "an assist must back someone who's quarreling" do
    sign_in_as identities(:pip)

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
  end

  test "roll a montage" do
    sign_in_as identities(:pip)
    get campaign_path(@campaign)
    assert_select "a[href=?]", new_campaign_montage_path(@campaign)

    get new_campaign_montage_path(@campaign)
    assert_select "input[type=checkbox]", 2

    assert_difference -> { @campaign.rolls.montage.count }, 1 do
      post campaign_montages_path(@campaign), params: { scene: "The climb", participants: {
        @tibbs.id => { in: "1", spark: 1 }, @bram.id => { in: "1" }
      } }
    end
    assert_redirected_to campaign_path(@campaign, anchor: "roll-log")
    assert_equal({ @tibbs.name => 3, "Bram" => 2 }, @campaign.rolls.montage.last.sides.to_h { [ _1["name"], _1["dice"].size ] })

    follow_redirect!
    assert_select "#table_feed .feed-item__question", "The climb"
    assert_select "#table_feed .feed-item__meta", /highest result is the scene's outcome/
  end

  test "a montage needs someone in it, and only your own spark" do
    sign_in_as identities(:pip)

    post campaign_montages_path(@campaign), params: { participants: { @tibbs.id => { spark: 1 } } }
    assert_select ".toast__message", "Pick who takes part in the montage."

    post campaign_montages_path(@campaign), params: { participants: { @bram.id => { in: "1", spark: 1 } } }
    assert_select ".toast__message", "Only Bram's player can spend their spark."
    assert_equal 0, @campaign.rolls.montage.count
  end
end
