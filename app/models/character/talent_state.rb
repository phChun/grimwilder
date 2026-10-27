# What a few talents keep track of between rolls (talent_state, by talent
# key; a talent's `state:` in config/talents.yml says which):
#
# - `omens` (Augury): two d6s rolled before each session; any rolled d6 at
#   the table can be swapped for one, which then erases (a follow-up).
# - `herbs` (Herbalism): two herb names made before each session, the
#   touchstones for its potions.
# - `frenzy` (Frenzy): in a frenzy for the scene, so its bonus applies.
# - `quarries` (Quarry): who this session's quarries are.
# - `enchantment` (Magus): the trait the weapon is enchanted with, until it's
#   ended for a potent effect.
# - `oath` (Oathsworn, P6 pg. 69): each tenet's violation, `violated` (a slash),
#   `heavy` (filled in) or `broken` (no atoning); 1 less smite for each. Two
#   broken make an Oathbreaker (Character::Oath). And Affirmation's spark.
# - `menagerie` (Monster Menagerie): which of the bonded creatures answers.
#
# A session clears all of it (and rolls new omens) except a paladin's tenets,
# which last until atoned; a scene's end ends a frenzy.
module Character::TalentState
  STATES = %w[ omens herbs frenzy quarries enchantment oath menagerie ].freeze
  VIOLATIONS = %w[ violated heavy broken ].freeze
  # Kept when a session clears the rest.
  LASTING = %w[ oathsworn ].freeze
  ENCHANTMENTS = %w[ flaming pulverizing seeking ].freeze
  HERB_COUNT = 2
  OMEN_COUNT = 2

  def talent_with_state(state)
    [ *talent_entries, *eldritch_talent_entries ].find { _1.state == state.to_s }
  end

  def omens
    Array(talent_state.dig("augury", "omens"))
  end

  def herbs
    Array(talent_state.dig("herbalism", "herbs"))
  end

  def quarries
    Array(talent_state.dig("quarry", "names"))
  end

  def enchantment
    talent_state.dig("magus", "trait")
  end

  # { "never flee" => "heavy" }: tenets in violation, and how badly.
  def tenet_violations
    talent_state.dig("oathsworn", "violations") || {}
  end

  def tenets_in_violation
    tenet_violations.size
  end

  def answering_creature
    talent_state.dig("monster-menagerie", "answering")
  end

  def in_frenzy?
    talent_with_state(:frenzy).present? && talent_state.dig("frenzy", "on") == true
  end

  # Before each session (Character#start_session!): new omens, no herbs or
  # quarries yet, out of any frenzy. Doesn't save.
  def reset_talent_state(random: Random)
    self.talent_state = talent_state.slice(*LASTING)
    self.talent_state = { "augury" => { "omens" => Array.new(OMEN_COUNT) { random.rand(1..6) } } } if talent_with_state(:omens)
  end

  def end_frenzy
    self.talent_state = talent_state.except("frenzy")
  end

  def set_herbs!(names)
    raise ArgumentError, "#{short_name} doesn't have Herbalism." unless talent_with_state(:herbs)

    update!(talent_state: talent_state.merge("herbalism" => { "herbs" => Array(names).map { _1.to_s.squish.first(40) }.compact_blank.first(HERB_COUNT) }))
  end

  # Ticks one of Quarry's designations and names the quarry.
  def designate_quarry!(name, by:)
    talent = talent_with_state(:quarries) or raise ArgumentError, "#{short_name} doesn't have Quarry."
    use = use_counters.find { _1.id == "#{talent.key}/designations" }
    name = name.to_s.squish.first(60).presence or raise ArgumentError, "Name the quarry."
    raise ArgumentError, "No designations left this session." unless use && uses_left(use).positive?

    update!(talent_uses: talent_uses.merge(use.id => uses_spent(use) + 1),
      talent_state: talent_state.merge("quarry" => { "names" => quarries + [ name ] }))
    Roll.note!(campaign: campaign, by: by, character: self, text: "#{short_name} marks #{name} as their quarry.") if campaign
  end

  # Frenzy (pg. 59): once per session by choice, ticking its use, or free when
  # bloodied or taking vex.
  def enter_frenzy!(by:, free: false)
    talent = talent_with_state(:frenzy) or raise ArgumentError, "#{short_name} doesn't have Frenzy."
    use = use_counters.find { _1.id == "#{talent.key}/frenzy" }
    raise ArgumentError, "#{short_name} is already in a frenzy." if in_frenzy?
    raise ArgumentError, "No frenzy left this session; it's free when bloodied or taking vex." unless free || (use && uses_left(use).positive?)

    uses = free ? talent_uses : talent_uses.merge(use.id => uses_spent(use) + 1)
    update!(talent_uses: uses, talent_state: talent_state.merge("frenzy" => { "on" => true }))
    Roll.note!(campaign: campaign, by: by, character: self, text: "#{short_name} enters a frenzy.") if campaign
  end

  def leave_frenzy!(by:)
    raise ArgumentError, "#{short_name} isn't in a frenzy." unless in_frenzy?

    end_frenzy
    save!
    Roll.note!(campaign: campaign, by: by, character: self, text: "#{short_name} comes out of the frenzy.") if campaign
  end

  # Magus: once per session, enchant the weapon with a trait, ticking the use.
  def enchant_weapon!(trait, by:)
    talent = talent_with_state(:enchantment) or raise ArgumentError, "#{short_name} doesn't have Magus."
    use = use_counters.find { _1.id == "#{talent.key}/enchant" }
    trait = trait.to_s.squish.downcase.first(40).presence or raise ArgumentError, "Give the weapon a trait."
    raise ArgumentError, "The weapon is already #{enchantment}." if enchantment
    raise ArgumentError, "No enchantment left this session." unless use && uses_left(use).positive?

    update!(talent_uses: talent_uses.merge(use.id => uses_spent(use) + 1), talent_state: talent_state.merge("magus" => { "trait" => trait }))
    Roll.note!(campaign: campaign, by: by, character: self, text: "#{short_name} enchants their weapon: #{trait}.") if campaign
  end

  # Ends the enchantment to produce a potent effect with the weapon.
  def end_enchantment!(by:)
    trait = enchantment or raise ArgumentError, "#{short_name}'s weapon isn't enchanted."

    update!(talent_state: talent_state.except("magus"))
    Roll.note!(campaign: campaign, by: by, character: self, text: "#{short_name} ends the #{trait} enchantment for a potent effect.") if campaign
  end

  # A tenet violated again: slashed, then filled in (heavy), then broken. The
  # second broken tenet makes the paladin an Oathbreaker.
  def violate_tenet!(tenet, by:)
    raise ArgumentError, "#{short_name} has no tenet like that." unless picks_for(talent_entry("oathsworn").choice("tenets")).include?(tenet)
    now = tenet_violations[tenet]
    raise ArgumentError, "That tenet is already broken." if now == "broken"

    after = VIOLATIONS[now ? VIOLATIONS.index(now) + 1 : 0]
    update!(talent_state: talent_state.merge("oathsworn" => { "violations" => tenet_violations.merge(tenet => after) }))
    Roll.note!(campaign: campaign, by: by, character: self, text: "#{short_name} #{{ "violated" => "violates", "heavy" => "is in heavy violation of", "broken" => "breaks" }[after]} a tenet: #{tenet}.") if campaign
    break_oath!(by: by) if after == "broken" && tenet_violations.values.count("broken") >= 2 && can_break_oath?
  end

  # A great deed atones for a tenet in violation; a broken one can't be.
  def atone_tenet!(tenet, by:)
    raise ArgumentError, "That tenet isn't in violation." unless tenet_violations.key?(tenet)
    raise ArgumentError, "A broken tenet can't be atoned for." if tenet_violations[tenet] == "broken"

    update!(talent_state: talent_state.merge("oathsworn" => { "violations" => tenet_violations.except(tenet) }))
    Roll.note!(campaign: campaign, by: by, character: self, text: "#{short_name} atones: #{tenet}.") if campaign
  end

  # Affirmation: once a session, spark for a player who joined a scene
  # involving the tenets (another character at the table).
  def affirm!(ally, by:)
    use = use_counters.find { _1.id == "oathsworn/affirmation" } or raise ArgumentError, "#{short_name} doesn't have Oathsworn."
    raise ArgumentError, "Affirmation is spent this session." unless uses_left(use).positive?
    raise ArgumentError, "Give it to another character at the table." unless campaign && ally.campaign_id == campaign_id && ally != self

    transaction do
      update!(talent_uses: talent_uses.merge(use.id => uses_spent(use) + 1))
      took = ally.settle_spark(take: true)
      ally.save!
      Roll.note!(campaign: campaign, by: by, character: self, text: "#{short_name}'s Affirmation: #{ally.short_name} #{took ? "takes spark" : "already has the most spark"}.")
    end
  end

  # Monster Menagerie: which bonded creature answers the next summons.
  def answer_with!(creature, by:)
    raise ArgumentError, "#{short_name} has no creature like that." unless picks_for(talent_entry("monster-menagerie").choice("creatures")).include?(creature)

    update!(talent_state: talent_state.merge("monster-menagerie" => { "answering" => creature }))
    Roll.note!(campaign: campaign, by: by, character: self, text: "#{creature} answers #{short_name}'s call.") if campaign
  end

  # An omen spent on a roll (Roll::FollowUps): erased once used. Doesn't save.
  def erase_omen(value)
    index = omens.index(value) or raise ArgumentError, "#{short_name} has no omen showing #{value}."
    self.talent_state = talent_state.merge("augury" => { "omens" => omens.dup.tap { _1.delete_at(index) } })
  end
end
