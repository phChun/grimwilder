require "test_helper"

class TalentChoicesTest < ActionDispatch::IntegrationTest
  setup do
    @tibbs = characters(:tibbs) # pip's Rogue, at gwen's table: Expertise is the core
  end

  test "the form lists a closed list as checkboxes, in the book's groups" do
    @tibbs.choose_for_talent!("expertise", "skills" => %w[ stealth ])
    sign_in_as identities(:pip)
    get edit_character_talent_choices_path(@tibbs, "expertise")

    assert_response :success
    assert_select "turbo-frame#modal h1", "Expertise"
    assert_equal [ "Above board", "Below table" ], css_select(".talent-choice__group-name").map(&:text)
    assert_select "input[type=checkbox][name='picks[skills][]']", 12
    assert_select "input[type=checkbox][value=stealth][checked]"
    assert_select ".talent-choice__count", "1 of 3"
    assert_select ".talent-choice__option", text: /Charm\s*Persuade with personality\./
  end

  test "an open list is a type-or-pick box per slot" do
    @tibbs.update!(level: 2, talent_keys: %w[ lucky wisps ])
    sign_in_as identities(:pip)
    get edit_character_talent_choices_path(@tibbs, "wisps")

    assert_select "input[type=text][name='picks[traits][]'][list=choice-traits-list]", 2
    assert_select "datalist#choice-traits-list option[value=Petty]"
  end

  test "the owner saves picks and goes back to the talent" do
    sign_in_as identities(:pip)
    patch character_talent_choices_path(@tibbs, "expertise"), params: { picks: { skills: [ "", "Charm", "stealth" ] } }

    assert_redirected_to character_path(@tibbs, anchor: "talent-expertise")
    assert_equal %w[ charm stealth ], @tibbs.reload.talent_choices.dig("expertise", "skills")

    patch character_talent_choices_path(@tibbs, "expertise"), params: { picks: { skills: [ "" ] } }
    assert_empty @tibbs.reload.talent_choices, "unticking every box clears them"
  end

  test "a bad pick shows the form again with what went wrong" do
    sign_in_as identities(:pip)
    patch character_talent_choices_path(@tibbs, "expertise"), params: { picks: { skills: %w[ charm parkour deception stealth ] } }

    assert_response :unprocessable_entity
    assert_select ".form-error", /room for 3 skills/
    assert_empty @tibbs.reload.talent_choices
  end

  test "the GM can pick for a player's character; other players can't; strangers get a 404" do
    sign_in_as identities(:gwen)
    patch character_talent_choices_path(@tibbs, "expertise"), params: { picks: { skills: %w[ network ] } }
    assert_equal %w[ network ], @tibbs.reload.talent_choices.dig("expertise", "skills")

    sign_out
    sign_in_as identities(:pip)
    get edit_character_talent_choices_path(characters(:bram), "weapon-mastery")
    assert_response :forbidden

    sign_out
    sign_in_as identities(:stranger)
    patch character_talent_choices_path(@tibbs, "expertise"), params: { picks: { skills: %w[ charm ] } }
    assert_response :not_found
  end

  test "a talent with nothing to pick, or one the character lacks, is a 404" do
    sign_in_as identities(:pip)
    @tibbs.update!(talent_keys: [ "lucky" ])
    get edit_character_talent_choices_path(@tibbs, "lucky")
    assert_response :not_found

    get edit_character_talent_choices_path(@tibbs, "flight")
    assert_response :not_found
  end

  test "the card shows the picks as chips and asks for the rest" do
    @tibbs.choose_for_talent!("expertise", "skills" => [ "sleight of hand" ])
    sign_in_as identities(:pip)
    get character_path(@tibbs)

    assert_select "#talent-expertise .talent-card__label", "Skills"
    assert_select "#talent-expertise .talent-card__pick", "Sleight of Hand"
    assert_select "#talent-expertise a.talent-card__pick-more[data-turbo-frame=modal][href=?]", edit_character_talent_choices_path(@tibbs, "expertise"), text: "Choose 2 more skills"
    assert_select "#talent-expertise-menu a[href=?]", edit_character_talent_choices_path(@tibbs, "expertise"), text: "Choose skills…"
  end

  test "touchstones are labelled as such, and other players see picks without the links" do
    ash = identities(:gwen).characters.create!(name: "Ash", path: "Sorcerer", brawn: 1, agility: 2, wits: 2, presence: 3, campaign: campaigns(:bramblewood))
    ash.choose_for_talent!("sorcery", "paths" => %w[ flame ])

    sign_in_as identities(:pip)
    get character_path(ash)
    assert_select "#talent-sorcery .talent-card__label", "Touchstones"
    assert_select "#talent-sorcery .talent-card__pick", "Flame"
    assert_select "#talent-sorcery .talent-card__pick-more", 0
  end

  test "over the cap after a level drop, the card says so" do
    @tibbs.update!(level: 3, talent_keys: %w[ lucky wisps flight ])
    @tibbs.choose_for_talent!("expertise", "skills" => %w[ charm parkour deception stealth ])
    @tibbs.update!(level: 1, talent_keys: %w[ lucky ])

    sign_in_as identities(:pip)
    get character_path(@tibbs)
    assert_select "#talent-expertise .talent-over", /room for 3 skills/
  end

  test "taking a talent with picks lands on its card" do
    @tibbs.update!(talent_keys: [])
    sign_in_as identities(:pip)
    post character_talents_path(@tibbs), params: { talent: "flight" }

    assert_redirected_to character_path(@tibbs, anchor: "talent-flight")
    assert_equal "Gibbletibble \"Tibbs\" took Flight. Choose 2 benefits on its card.", flash[:notice]
  end

  test "the catalog says what a talent asks you to pick" do
    get talents_path
    assert_select "#talent-artificial-parts .talent__choices", "Choose 3 perks and 1 drawback"
  end

  test "spell theorems: a name box and a school per theorem, the spell crucible to roll on, and the school on the card" do
    mo = identities(:pip).characters.create!(name: "Mo", path: "Wizard", brawn: 1, agility: 2, wits: 3, presence: 2, campaign: campaigns(:bramblewood))
    sign_in_as identities(:pip)

    get edit_character_talent_choices_path(mo, "spellcraft")
    assert_select "input[type=text][name='picks[theorems][]']", 4
    assert_select "select[name='schools[theorems][]']", 4
    assert_select "select[name='schools[theorems][]'] option[value=necromancy]"
    assert_select "fieldset[data-crucible=spell][data-words='2']"
    assert_select "turbo-frame#crucible[src=?][loading=lazy]", crucible_path("spell", embed: 1)

    patch character_talent_choices_path(mo, "spellcraft"), params: { picks: { theorems: [ "wild fire", "frost ring", "", "" ] }, schools: { theorems: [ "evocation", "", "illusion", "" ] } }
    assert_redirected_to character_path(mo, anchor: "talent-spellcraft")
    assert_equal [ "wild fire (evocation)", "frost ring" ], mo.reload.talent_choices.dig("spellcraft", "theorems")

    get edit_character_talent_choices_path(mo, "spellcraft")
    assert_select "input[name='picks[theorems][]'][value='wild fire'] + select option[value=evocation][selected]"

    get character_path(mo)
    assert_select "#talent-spellcraft .talent-card__pick", [ "Wild Fire · Evocation", "Frost Ring" ].first
  end

  test "Mastered Theorem picks from the theorems, once there are some" do
    mo = identities(:pip).characters.create!(name: "Mo", path: "Wizard", brawn: 1, agility: 2, wits: 3, presence: 2, talent_keys: [ "mastered-theorem" ])
    sign_in_as identities(:pip)

    get edit_character_talent_choices_path(mo, "mastered-theorem")
    assert_select ".field__hint", /Choose your spell theorems first/
    assert_select "input[type=checkbox]", 0

    mo.choose_for_talent!("spellcraft", "theorems" => [ "wild fire (evocation)", "frost ring" ])
    get edit_character_talent_choices_path(mo, "mastered-theorem")
    assert_select "input[type=checkbox][value='wild fire (evocation)'] + span", "Wild Fire · Evocation"
    assert_select "turbo-frame#crucible", 0, "nothing to roll: it picks from the theorems"

    patch character_talent_choices_path(mo, "mastered-theorem"), params: { picks: { theorem: [ "", "wild fire (evocation)" ] } }
    assert_equal [ "wild fire (evocation)" ], mo.reload.talent_choices.dig("mastered-theorem", "theorem")
  end

  test "the patron rolls natures and desires on their own tables of one crucible" do
    vex = identities(:pip).characters.create!(name: "Vex", path: "Warlock", brawn: 1, agility: 2, wits: 2, presence: 3, talent_keys: [ "affliction" ])
    sign_in_as identities(:pip)
    get edit_character_talent_choices_path(vex, "pact")

    assert_select "fieldset[data-crucible=patron][data-table=Nature] input[name='picks[natures][]']", 2
    assert_select "fieldset[data-crucible=patron][data-table=Desires] input[name='picks[desires][]']", 2
    assert_select "turbo-frame#crucible[src=?]", crucible_path("patron", embed: 1)
    assert_select "input[type=checkbox][name='picks[following][]']", 3

    patch character_talent_choices_path(vex, "pact"), params: { picks: { natures: [ "Serpent", "void" ], name: [ "The Coiled One" ], following: [ "", "few" ] } }
    assert_equal({ "natures" => [ "Serpent", "void" ], "name" => [ "The Coiled One" ], "following" => [ "few" ] }, vex.reload.talent_choices["pact"])
  end

  test "Hidden Magic's words are burned by name on the card" do
    nell = identities(:pip).characters.create!(name: "Nell", path: "Witch", brawn: 1, agility: 2, wits: 2, presence: 3, campaign: campaigns(:bramblewood))
    nell.choose_for_talent!("hidden-magic", "words" => %w[ star storm ])
    sign_in_as identities(:pip)

    get character_path(nell)
    assert_select "#talent-hidden-magic .use-words button.use-word", [ "Star", "Storm" ].first
    assert_select "#talent-hidden-magic .use-words button.use-word", 2
    assert_select "#talent-hidden-magic .talent-card__pick", 0, "the words show as the boxes, not twice"
    assert_select "#talent-hidden-magic .use-tracker__resets", "2 left · resets each session"
    assert_select "#talent-hidden-magic a.talent-card__pick-more", "Choose 4 more words of power"

    patch character_talent_uses_path(nell), params: { use: "hidden-magic/words", name: "storm", note: "1" }
    assert_equal [ "storm" ], nell.reload.burned_names(Talent.find("hidden-magic").uses.sole)
    assert_equal "Nell burns storm", campaigns(:bramblewood).rolls.note.last.question

    get character_path(nell)
    assert_select "#talent-hidden-magic button.use-word--burned[aria-pressed=true]", "Storm"
    assert_select "#talent-hidden-magic .use-tracker__resets", "1 left · resets each session"
  end

  test "Infusion's known touchstones are offered, not asked for" do
    kit = identities(:pip).characters.create!(name: "Kit", path: "Artificer", brawn: 1, agility: 2, wits: 3, presence: 2)
    assert_empty kit.choices_to_make

    sign_in_as identities(:pip)
    get character_path(kit)
    assert_select "#talent-infusion a.talent-card__pick-more", "Optional: choose 6 touchstones"
    assert_select ".arcana-grants__item", /Infusion: 0 of 2 major arcana \(optional\)/
  end
end
