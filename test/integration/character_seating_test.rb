require "test_helper"

class CharacterSeatingTest < ActionDispatch::IntegrationTest
  setup do
    @campaign = campaigns(:bramblewood)
    @wren = characters(:loner)
    identities(:stranger).memberships.create!(campaign: @campaign, role: "player")
  end

  test "seat a character from the list, and the table hears about it" do
    sign_in_as identities(:stranger)
    get characters_path
    assert_select "form.seat-form[action=?]", character_seat_path(@wren) do
      assert_select "option[selected]", 0
      assert_select "option[value=?]", @campaign.id.to_s, @campaign.name
    end

    assert_difference -> { @campaign.rolls.where(kind: "note").count }, 1 do
      patch character_seat_path(@wren), params: { campaign_id: @campaign.id }, headers: { "HTTP_REFERER" => characters_url }
    end
    assert_redirected_to characters_url
    assert_equal @campaign, @wren.reload.campaign
    assert_equal "Stranger seats Wren at the table.", @campaign.rolls.last.question
  end

  test "take a character away from the table from the sheet, with its talent pools" do
    @wren.update!(campaign: @campaign)
    pool = @wren.talent_pools.create!(campaign: @campaign, name: "Wren: Quarry", kind: "task", starting_size: 2, size: 2, use_key: "x/y")
    sign_in_as identities(:stranger)
    get character_path(@wren)
    assert_select ".adjust form.seat-form option[selected][value=?]", @campaign.id.to_s

    patch character_seat_path(@wren), params: { campaign_id: "" }
    assert_redirected_to character_path(@wren)
    assert_nil @wren.reload.campaign
    assert_not Pool.exists?(pool.id)
    assert_equal "Wren leaves the table.", @campaign.rolls.last.question
  end

  test "only into your own campaigns, and only your own characters" do
    sign_in_as identities(:stranger)
    other = Campaign.create!(name: "Elsewhere")

    patch character_seat_path(@wren), params: { campaign_id: other.id }
    assert_response :not_found
    patch character_seat_path(characters(:tibbs)), params: { campaign_id: @campaign.id }
    assert_response :not_found
    assert_nil @wren.reload.campaign
  end

  test "an up-for-grabs character stays put until it's picked" do
    bram = characters(:bram)
    bram.update!(up_for_grabs: true)
    sign_in_as identities(:gwen)

    get characters_path
    assert_select "form[action=?]", character_seat_path(bram), 0
    patch character_seat_path(bram), params: { campaign_id: "" }
    assert_equal @campaign, bram.reload.campaign
  end
end
