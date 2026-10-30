require "test_helper"

class CampaignBriefTest < ActionDispatch::IntegrationTest
  setup do
    @campaign = campaigns(:bramblewood)
    @campaign.update!(pitch: "Smugglers on a haunted river.", setting: "The Mirelands", group_arc: "uncover the truth", optional_rules: [ "vigor_pool" ])
    @tibbs, @bram = characters(:tibbs), characters(:bram)
    @tibbs.update!(traits: [ "quick-witted", "curious" ], not_trait: "patient", bloodied: true, notes: "Owes the ferryman.",
      bonds: [ { "character_id" => @bram.id, "to" => @bram.name, "bond" => "tense rivalry" }, { "to" => "Old Hesk", "bond" => "owes a debt" } ])
  end

  test "the brief has the campaign's pitch and each character's story, and no stats" do
    markdown = Campaign::Brief.new(@campaign).to_markdown

    assert_match "# #{@campaign.name}", markdown
    assert_match "*Smugglers on a haunted river.*", markdown
    assert_match "- **Group arc:** Uncover the Truth", markdown
    assert_match "- **Optional rules in play:** Vigor pool", markdown
    assert_match "### #{@tibbs.name}", markdown
    assert_match "- **Traits:** Quick-Witted, Curious; not Patient", markdown
    assert_match "- **Bonds:** #{@bram.short_name}: tense rivalry; Old Hesk: owes a debt", markdown
    assert_match "- **Hurt right now:** Bloodied", markdown
    assert_match "- **Notes:** Owes the ferryman.", markdown
    assert_match "(core)", markdown
    assert_no_match(/Brawn|Agility \d|spark/i, markdown)
  end

  test "the GM copies it from the table; players can't" do
    sign_in_as identities(:gwen)
    get campaign_table_path(@campaign)
    assert_select "a[href=?][data-turbo-frame=modal]", campaign_brief_path(@campaign), "Copy for an AI"

    get campaign_brief_path(@campaign), headers: { "Turbo-Frame" => "modal" }
    assert_select "turbo-frame#modal textarea#brief_markdown", /### #{Regexp.escape(@tibbs.name)}/
    assert_select "button[data-action='copy-text#copy']", "Copy Markdown"
  end

  test "players at the table are refused" do
    sign_in_as identities(:pip)
    get campaign_brief_path(@campaign)
    assert_response :forbidden
  end
end
