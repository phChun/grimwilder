require "test_helper"

# Picks a talent asks for (Character::TalentChoices).
class CharacterTalentChoicesTest < ActiveSupport::TestCase
  setup do
    @tibbs = characters(:tibbs) # a Rogue: Expertise is the core
    @skills = Talent.find("expertise").choice(:skills)
  end

  test "slots grow with the level" do
    assert_equal [ 3, 4, 4, 5 ], [ 1, 3, 5, 6 ].map { @tibbs.level = _1; @tibbs.choice_slots(@skills) }
  end

  test "picks from a closed list take the book's spelling" do
    @tibbs.choose_for_talent!("expertise", "skills" => [ "Stealth", " sleight  of  hand ", "" ])

    assert_equal({ "expertise" => { "skills" => [ "stealth", "sleight of hand" ] } }, @tibbs.reload.talent_choices)
    assert_equal [ "stealth", "sleight of hand" ], @tibbs.picks_for(@skills)
    assert_equal 1, @tibbs.choices_left(@skills)
    assert_equal [ [ "expertise", "skills", 1 ] ], @tibbs.choices_to_make.map { |talent, choice, left| [ talent.key, choice.key, left ] }
  end

  test "a closed list refuses anything else; an open one takes the player's own" do
    error = assert_raises(ActiveRecord::RecordInvalid) { @tibbs.choose_for_talent!("expertise", "skills" => [ "juggling" ]) }
    assert_match(/"juggling" isn't one of Expertise's skills/, error.message)

    @tibbs.reload.update!(level: 2, talent_keys: [ "wisps", "lucky" ])
    @tibbs.choose_for_talent!("wisps", "traits" => [ "petty", "smells of rain" ])
    assert_equal [ "petty", "smells of rain" ], @tibbs.reload.talent_choices.dig("wisps", "traits")
  end

  test "no more than the slots, and no pick twice" do
    assert_raises(ActiveRecord::RecordInvalid) { @tibbs.choose_for_talent!("expertise", "skills" => %w[ charm parkour deception stealth ]) }
    error = assert_raises(ActiveRecord::RecordInvalid) { @tibbs.choose_for_talent!("expertise", "skills" => %w[ charm Charm ]) }
    assert_match(/same skill twice/, error.message)
  end

  test "Sorcery needs a path and a technique once the slots are full" do
    sorcerer = identities(:pip).characters.create!(name: "Ash", path: "Sorcerer", brawn: 1, agility: 2, wits: 2, presence: 3)

    sorcerer.choose_for_talent!("sorcery", "paths" => %w[ flame frost ])
    error = assert_raises(ActiveRecord::RecordInvalid) { sorcerer.choose_for_talent!("sorcery", "paths" => %w[ flame frost stone shadow ]) }
    assert_match(/at least 1 from Techniques/, error.message)

    sorcerer.choose_for_talent!("sorcery", "paths" => %w[ flame frost stone attack ], "twist" => [ "Curse" ])
    assert_equal({ "paths" => %w[ flame frost stone attack ], "twist" => [ "curse" ] }, sorcerer.reload.talent_choices["sorcery"])
  end

  test "dropping a level leaves the picks, warns, and other saves still work" do
    @tibbs.update!(level: 3, talent_keys: %w[ lucky wisps flight ])
    @tibbs.choose_for_talent!("expertise", "skills" => %w[ charm parkour deception stealth ])

    @tibbs.update!(level: 1, talent_keys: [ "wisps" ])
    assert_equal 1, @tibbs.extra_choices(@skills)
    assert_equal 4, @tibbs.picks_for(@skills).size

    @tibbs.update!(spark: 0)
    @tibbs.choose_for_talent!("wisps", "traits" => [ "petty" ])
    assert_equal [ "petty" ], @tibbs.reload.talent_choices.dig("wisps", "traits")

    assert_raises(ActiveRecord::RecordInvalid) { @tibbs.choose_for_talent!("expertise", "skills" => %w[ charm parkour deception sabotage ]) }
    @tibbs.reload.choose_for_talent!("expertise", "skills" => %w[ charm parkour deception ])
  end

  test "clearing every pick removes the talent's entry" do
    @tibbs.choose_for_talent!("expertise", "skills" => %w[ charm ])
    @tibbs.choose_for_talent!("expertise", "skills" => [ "" ])
    assert_empty @tibbs.reload.talent_choices
  end

  test "only the character's own talents, and only their choices" do
    assert_raises(ActiveRecord::RecordNotFound) { @tibbs.choose_for_talent!("sorcery", "paths" => %w[ flame ]) }
    assert_raises(ActiveRecord::RecordNotFound) { @tibbs.choose_for_talent!("expertise", "tricks" => %w[ fetch ]) }

    @tibbs.talent_choices = { "flight" => { "benefits" => [ "agile" ] } }
    assert_not @tibbs.valid?
    assert_match(/doesn't have \(flight\)/, @tibbs.errors.full_messages.to_sentence)
  end

  test "removing a talent drops its picks; a re-skin keeps them" do
    @tibbs.update!(level: 2, talent_keys: %w[ lucky flight ])
    @tibbs.choose_for_talent!("flight", "benefits" => %w[ swift ])
    @tibbs.reskin_talent!("flight", "name" => "Gliding Cloak")
    assert_equal [ "swift" ], @tibbs.reload.talent_choices.dig("flight", "benefits")

    @tibbs.remove_talent!("flight")
    assert_empty @tibbs.reload.talent_choices
  end

  test "Eldritch Talents can have picks, and lose them when removed" do
    vex = identities(:pip).characters.create!(name: "Vex", path: "Warlock", brawn: 1, agility: 2, wits: 2, presence: 3, talent_keys: [ "affliction" ])
    vex.add_eldritch_talent!("eldritch-affinity")

    vex.choose_for_talent!("eldritch-affinity", "paths" => %w[ shadow hinder Influence ])
    assert_equal %w[ shadow hinder influence ], vex.reload.talent_choices.dig("eldritch-affinity", "paths")
    assert_not_includes vex.choices_to_make.map { _1.first.key }, "eldritch-affinity"

    vex.remove_eldritch_talent!("eldritch-affinity")
    assert_empty vex.reload.talent_choices
  end

  test "spell theorems keep their school, which has to be a real one" do
    wizard = identities(:pip).characters.create!(name: "Mo", path: "Wizard", brawn: 1, agility: 2, wits: 3, presence: 2)

    wizard.choose_for_talent!("spellcraft", "theorems" => [ "Wild  Fire (Evocation)", "fire sentinel (transmutation)", "frost ring" ])
    assert_equal [ "Wild Fire (evocation)", "fire sentinel (transmutation)", "frost ring" ], wizard.reload.talent_choices.dig("spellcraft", "theorems")

    error = assert_raises(ActiveRecord::RecordInvalid) { wizard.choose_for_talent!("spellcraft", "theorems" => [ "wild fire (pyromancy)" ]) }
    assert_match(/"pyromancy" isn't a school/, error.message)
    error = assert_raises(ActiveRecord::RecordInvalid) { wizard.reload.choose_for_talent!("spellcraft", "theorems" => [ "wild fire (evocation)", "Wild fire (illusion)" ]) }
    assert_match(/same theorem twice/, error.message)
  end

  test "Mastered Theorem picks from the character's own theorems" do
    wizard = identities(:pip).characters.create!(name: "Mo", path: "Wizard", brawn: 1, agility: 2, wits: 3, presence: 2, talent_keys: [ "mastered-theorem" ])
    mastered = Talent.find("mastered-theorem").choice(:theorem)
    assert_not wizard.choice_open?(mastered)
    assert_empty wizard.choice_options(mastered)

    wizard.choose_for_talent!("spellcraft", "theorems" => [ "wild fire (evocation)", "frost ring" ])
    assert_equal [ "wild fire (evocation)", "frost ring" ], wizard.choice_options(mastered)

    wizard.choose_for_talent!("mastered-theorem", "theorem" => [ "Frost Ring" ])
    assert_equal [ "frost ring" ], wizard.reload.talent_choices.dig("mastered-theorem", "theorem")
    assert_raises(ActiveRecord::RecordInvalid) { wizard.choose_for_talent!("mastered-theorem", "theorem" => [ "ice storm" ]) }
  end

  test "Bailiwick without Hidden Magic: the player names their own word" do
    # Witch only in the CE, so a Rogue can't take it now; a sheet that already had it keeps it.
    @tibbs.update_columns(talent_keys: [ "bailiwick" ])
    bailiwick = Talent.find("bailiwick").choice(:word)
    assert @tibbs.choice_open?(bailiwick)

    @tibbs.choose_for_talent!("bailiwick", "word" => [ "star" ])
    assert_equal [ "star" ], @tibbs.reload.picks_for(bailiwick)
  end

  test "Specialty School picks from the book's schools" do
    @tibbs.update!(talent_keys: [ "specialty-school" ])
    @tibbs.choose_for_talent!("specialty-school", "school" => [ "Illusion" ])
    assert_equal [ "illusion" ], @tibbs.reload.talent_choices.dig("specialty-school", "school")
    assert_raises(ActiveRecord::RecordInvalid) { @tibbs.choose_for_talent!("specialty-school", "school" => [ "pyromancy" ]) }
  end

  test "Hidden Magic burns its words by name, and a session brings them back" do
    witch = identities(:pip).characters.create!(name: "Nell", path: "Witch", brawn: 1, agility: 2, wits: 2, presence: 3)
    words = Talent.find("hidden-magic").uses.sole
    assert_equal [ nil ] * 6, witch.use_box_names(words)

    witch.choose_for_talent!("hidden-magic", "words" => %w[ star storm grace ])
    assert_equal [ "star", "storm", "grace", nil, nil, nil ], witch.use_box_names(words)

    witch.toggle_named_use!("hidden-magic/words", "storm")
    witch.toggle_named_use!("hidden-magic/words", "star")
    assert_equal %w[ storm star ], witch.reload.burned_names(words)
    assert_equal 2, witch.uses_spent(words)
    assert_equal 4, witch.uses_left(words)

    witch.toggle_named_use!("hidden-magic/words", "storm")
    assert_equal %w[ star ], witch.reload.burned_names(words)
    assert_raises(ArgumentError) { witch.toggle_named_use!("hidden-magic/words", "moon") }

    witch.reset_talent_uses(per: :session)
    assert_empty witch.burned_names(words)
  end
end
