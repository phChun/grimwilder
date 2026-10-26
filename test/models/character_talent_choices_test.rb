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
    @tibbs.choose_for_talent!("expertise", "skills" => [ "Stealth", " forgery  &  disguise ", "" ])

    assert_equal({ "expertise" => { "skills" => [ "stealth", "forgery & disguise" ] } }, @tibbs.reload.talent_choices)
    assert_equal [ "stealth", "forgery & disguise" ], @tibbs.picks_for(@skills)
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
    assert_raises(ActiveRecord::RecordInvalid) { @tibbs.choose_for_talent!("expertise", "skills" => %w[ duel evade lying stealth ]) }
    error = assert_raises(ActiveRecord::RecordInvalid) { @tibbs.choose_for_talent!("expertise", "skills" => %w[ duel Duel ]) }
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
    @tibbs.choose_for_talent!("expertise", "skills" => %w[ duel evade lying stealth ])

    @tibbs.update!(level: 1, talent_keys: [ "wisps" ])
    assert_equal 1, @tibbs.extra_choices(@skills)
    assert_equal 4, @tibbs.picks_for(@skills).size

    @tibbs.update!(spark: 0)
    @tibbs.choose_for_talent!("wisps", "traits" => [ "petty" ])
    assert_equal [ "petty" ], @tibbs.reload.talent_choices.dig("wisps", "traits")

    assert_raises(ActiveRecord::RecordInvalid) { @tibbs.choose_for_talent!("expertise", "skills" => %w[ duel evade lying sabotage ]) }
    @tibbs.reload.choose_for_talent!("expertise", "skills" => %w[ duel evade lying ])
  end

  test "clearing every pick removes the talent's entry" do
    @tibbs.choose_for_talent!("expertise", "skills" => %w[ duel ])
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
    assert_empty vex.choices_to_make

    vex.remove_eldritch_talent!("eldritch-affinity")
    assert_empty vex.reload.talent_choices
  end
end
