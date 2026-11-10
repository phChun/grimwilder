require "test_helper"

class ArcanaTest < ActionDispatch::IntegrationTest
  setup do
    @tibbs = characters(:tibbs) # pip's, at gwen's table
    @campaign = campaigns(:bramblewood)
  end

  test "the owner adds an arcana from the sheet's modal form" do
    sign_in_as identities(:pip)

    get character_path(@tibbs)
    assert_select "#arcana a[href=?][data-turbo-frame=modal]", new_character_arcanum_path(@tibbs), "Add arcana"

    get new_character_arcanum_path(@tibbs)
    assert_select "turbo-frame#modal h1", "New arcana"
    assert_select "input[type=radio][name='arcanum[function]']", 10
    assert_select "input[type=radio][name='arcanum[tier]'][value=minor][checked]"
    assert_select "input[name='arcanum[touchstones][]']", 3
    assert_select "fieldset[data-crucible=arcana] turbo-frame#crucible[src=?]", crucible_path("arcana", embed: 1)

    post character_arcana_path(@tibbs), params: { arcanum: { name: "Lantern of Echoes", function: "reveal", tier: "major", power_pool: "1", touchstones: [ "echo", "light", "" ], description: "Shows what was said here." } }
    lantern = @tibbs.arcana.sole
    assert_redirected_to character_path(@tibbs, anchor: "arcanum-#{lantern.id}")
    assert_equal %w[ echo light ], lantern.touchstones
    assert_equal 4, lantern.pool.size
    assert_equal "Gibbletibble \"Tibbs\" gains Lantern of Echoes (major arcana)", @campaign.rolls.note.last.question

    get character_path(@tibbs)
    assert_select "#arcanum-#{lantern.id} .talent-card__name", "Lantern of Echoes"
    assert_select "#arcanum-#{lantern.id} .talent-card__source", "Major arcana"
    assert_equal %w[ Reveal Echo Light ], css_select("#arcanum-#{lantern.id} .talent-card__pick").map(&:text)
    assert_select "#arcanum-#{lantern.id} .pool-rows--sheet"
  end

  test "a bad arcana shows the form again" do
    sign_in_as identities(:pip)
    post character_arcana_path(@tibbs), params: { arcanum: { name: "", function: "juggle" } }

    assert_response :unprocessable_entity
    assert_select ".form-error", /Name can't be blank/
    assert_empty @tibbs.arcana
  end

  test "the GM can change a player's arcana; other players can't; strangers get a 404" do
    lantern = @tibbs.arcana.create!(name: "Lantern", function: "reveal")

    sign_in_as identities(:gwen)
    patch character_arcanum_path(@tibbs, lantern), params: { arcanum: { name: "Lantern of Echoes" } }
    assert_equal "Lantern of Echoes", lantern.reload.name

    sign_out
    sign_in_as identities(:pip)
    get new_character_arcanum_path(characters(:bram))
    assert_response :forbidden

    sign_out
    sign_in_as identities(:stranger)
    delete character_arcanum_path(@tibbs, lantern)
    assert_response :not_found
    assert Arcanum.exists?(lantern.id)
  end

  test "other viewers see arcana without the controls" do
    @tibbs.arcana.create!(name: "Scroll of Mending", function: "restore", expendable: true)
    bram = characters(:bram)
    bram.arcana.create!(name: "Gwen's Ring", function: "protect", expendable: true)

    sign_in_as identities(:pip)
    get character_path(bram)
    assert_select "#arcana .talent-card__name", "Gwen's Ring"
    assert_select "#arcana a", 0
    assert_select "#arcana form", 0
  end

  test "an expendable arcana is used up, logged, and can be put back" do
    scroll = @tibbs.arcana.create!(name: "Scroll of Mending", function: "restore", expendable: true)
    sign_in_as identities(:pip)

    get character_path(@tibbs)
    assert_select "#arcanum-#{scroll.id} form[action=?] button", character_arcanum_use_path(@tibbs, scroll), "Use it up"

    post character_arcanum_use_path(@tibbs, scroll)
    assert scroll.reload.used?
    assert_equal "Gibbletibble \"Tibbs\" uses up Scroll of Mending", @campaign.rolls.note.last.question

    get character_path(@tibbs)
    assert_select "#arcanum-#{scroll.id}.arcanum-card--used .talent-card__source", /Used up/

    delete character_arcanum_use_path(@tibbs, scroll)
    assert_not scroll.reload.used?
  end

  test "talents that grant arcana say so, and preset the form" do
    @tibbs.update!(level: 2, talent_keys: %w[ archivist trophies ])
    sign_in_as identities(:pip)

    get character_path(@tibbs)
    assert_select ".arcana-grants__item", /Archivist: 0 of 2 minor arcana/
    assert_select ".arcana-grants__item", /Trophies: 0 of 1 major expendable arcana/
    assert_select ".arcana-grants__item a[href=?]", new_character_arcanum_path(@tibbs, tier: "major", source: "trophies", expendable: 1)

    get new_character_arcanum_path(@tibbs, tier: "major", source: "trophies", expendable: 1)
    assert_select "h1", "Arcana from Trophies"
    assert_select "input[type=hidden][name='arcanum[source]'][value=trophies]"
    assert_select "input[type=radio][name='arcanum[tier]'][value=major][checked]"
    assert_select "input[type=checkbox][name='arcanum[expendable]'][checked]"

    post character_arcana_path(@tibbs), params: { arcanum: { name: "Wyvern Fang", function: "attack", tier: "major", expendable: "1", source: "trophies" } }
    assert_equal "trophies", @tibbs.arcana.sole.source

    get character_path(@tibbs)
    assert_select ".arcana-grants__item", /Trophies: 1 of 1 major expendable arcana/
  end

  test "a source the character has no talent for is dropped" do
    sign_in_as identities(:pip)
    post character_arcana_path(@tibbs), params: { arcanum: { name: "Ring", function: "protect", source: "archivist" } }
    assert_nil @tibbs.arcana.sole.source
  end

  test "Magnum Opus: roll this session's touchstones, then lock one in" do
    @tibbs.update!(level: 2, talent_keys: %w[ magnum-opus lucky ])
    opus = @tibbs.arcana.create!(name: "The Great Work", function: "summon", tier: "mythic", power_pool: true, source: "magnum-opus")
    sign_in_as identities(:pip)

    get character_path(@tibbs)
    assert_select "#arcanum-#{opus.id} .arcanum-card__opus", /0 of 3 locked in/
    assert_select "#arcanum-#{opus.id} form[action=?] button", character_arcanum_opus_path(@tibbs, opus), "Roll this session's touchstones"

    post character_arcanum_opus_path(@tibbs, opus)
    rolled = opus.reload.rolled_touchstones
    assert_equal 3, rolled.size

    get character_path(@tibbs)
    assert_select "#arcanum-#{opus.id} .arcanum-card__opus button", 3

    patch character_arcanum_opus_path(@tibbs, opus), params: { touchstone: rolled.last }
    assert_equal [ rolled.last ], opus.reload.touchstones
    assert_equal "Gibbletibble \"Tibbs\" locks #{rolled.last} into The Great Work", @campaign.rolls.note.last.question

    patch character_arcanum_opus_path(@tibbs, opus), params: { touchstone: rolled.first }
    assert_redirected_to character_path(@tibbs, anchor: "arcanum-#{opus.id}")
    assert_equal "Roll before locking a touchstone in.", flash[:alert]
  end

  test "rolling an arcana's pool from the sheet comes back to the arcana" do
    ring = @tibbs.arcana.create!(name: "Ring of Gusts", function: "traverse", power_pool: true)
    sign_in_as identities(:pip)

    post campaign_pool_roll_path(@campaign, ring.pool), params: { return_to: "character" }
    assert_redirected_to character_path(@tibbs, anchor: "arcanum-#{ring.id}")
  end

  test "the form offers the optional additions, and the card shows them" do
    sign_in_as identities(:pip)
    get new_character_arcanum_path(@tibbs)
    assert_select "input[type=checkbox][name='arcanum[additions][]'][value=unique_reset]"

    post character_arcana_path(@tibbs), params: { arcanum: { name: "Whispering Skull", function: "reveal", tier: "major", additions: [ "", "sentient", "curse" ], limitations: "Lies when the moon is new." } }
    get character_path(@tibbs)
    assert_equal %w[ Sentient Curse ], css_select(".arcanum-card__limits .talent-card__label").map(&:text)
    assert_select ".arcanum-card__limits", /Lies when the moon is new\./
    assert_select ".arcanum-card__limits .talent-card__label", text: "Limits", count: 0

    sign_out
    sign_in_as identities(:gwen)
    @tibbs.arcana.create!(name: "Rope of Knots", function: "protect", limitations: "Only knots it already knows.")
    get character_path(@tibbs)
    assert_select "#arcanum-#{@tibbs.arcana.last.id} .arcanum-card__limits .talent-card__label", "Limits"
  end

  test "a counted arcana counts up and down; edit and remove sit at the bottom of its card" do
    potions = @tibbs.arcana.create!(name: "Healing potion", function: "restore", expendable: true, counted: true, quantity: 3)
    ring = @tibbs.arcana.create!(name: "Ring", function: "protect")
    sign_in_as identities(:pip)

    get character_path(@tibbs)
    assert_select "#arcanum-#{potions.id} details.talent-card__fold summary .talent-card__summary", /\A3 carried · Minor expendable arcana · Restore/
    assert_select "#arcanum-#{potions.id} .talent-card__actions .use-tally__count", "3"
    assert_select "#arcanum-#{potions.id} .talent-card__actions a[href=?]", edit_character_arcanum_path(@tibbs, potions), "Edit"
    assert_select "#arcanum-#{potions.id} .talent-card__actions form[action=?] button", character_arcanum_path(@tibbs, potions), "Remove"
    assert_select ".arcanum-card .talent-card__more-menu", 0
    assert_select "#arcanum-#{ring.id} .use-tally__count", 0

    patch character_arcanum_count_path(@tibbs, potions), params: { by: -1 }
    assert_redirected_to character_path(@tibbs, anchor: "arcanum-#{potions.id}")
    assert_equal 2, potions.reload.quantity

    patch character_arcanum_count_path(@tibbs, ring), params: { by: 1 }
    assert_response :not_found

    patch character_arcanum_path(@tibbs, ring), params: { arcanum: { counted: "1", quantity: "2" } }
    assert_equal [ true, 2 ], ring.reload.values_at(:counted, :quantity)
  end
end
