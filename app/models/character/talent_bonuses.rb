# What a character's talents add to a roll (Talent::Bonus): +1d when the
# situation fits, which the player ticks in the roll setup (or, for a story
# roll or montage, at the roll call), and the ones that always apply
# (Oathsworn's +1d for each thorn from harm, Lightning Reflexes on an Agility
# defense, Jack of All Trades' montages). The roll records each by name, so
# the log says where a die came from.
module Character::TalentBonuses
  # [talent, bonus] pairs the stat card's setup offers: the talent as this
  # character has it (re-skinned), so the tick reads with its own name.
  def talent_bonuses_for(stat)
    [ *talent_entries, *eldritch_talent_entries ].flat_map do |talent|
      talent.bonuses.select { _1.for_stat?(stat) && bonus_fits?(_1, stat) }.map { [ talent, _1 ] }
    end
  end

  # The same for a story roll or montage at a roll call (RollCall).
  def talent_bonuses_for_call(kind)
    [ *talent_entries, *eldritch_talent_entries ].flat_map do |talent|
      talent.bonuses.select { !_1.assist && _1.on.include?(kind.to_s) }.map { [ talent, _1 ] }
    end
  end

  # What this character brings when assisting someone's action or defense
  # roll: Guardian's +1d on a defense, Teamwork's 5s as 6s.
  def assist_bonuses
    [ *talent_entries, *eldritch_talent_entries ].flat_map do |talent|
      talent.bonuses.select(&:assist).map { [ talent, _1 ] }
    end
  end

  def assist_bonuses_rolled(mode, ticked)
    picked_bonuses(assist_bonuses, ticked, "an assist").select { _2.on.include?(mode.to_s) }.map { |talent, bonus| [ talent, bonus, bonus.dice ] }
  end

  # The assist's dice for the roll's `assists`: its own 1d, then 1d for each
  # die its talents add, named by the talent. Teamwork counts every one's 5s
  # as 6s.
  def assist_entries(rolled, random: Random)
    counts_as = rolled.filter_map { _2.counts_as }.first
    base = { "character_id" => id, "name" => name, "counts_as" => counts_as }.compact
    [ base.merge("die" => random.rand(1..6)) ] +
      rolled.flat_map { |talent, _, dice| Array.new(dice) { base.merge("die" => random.rand(1..6), "talent" => talent.name) } }
  end

  # Teamwork's montage rule (Roll::Montage); its assist rule is a bonus.
  def teamwork?
    [ *talent_entries, *eldritch_talent_entries ].any? { _1.key == "teamwork" }
  end

  def bonus_dice(bonus, stat = nil)
    if bonus.per_mark then Grimwild::STATS.count { marked?(_1) }
    elsif bonus.harm then harm_reasons(stat).size
    else bonus.dice
    end
  end

  # Thorns it adds that nothing removes: Awakened Mind's instability.
  def bonus_thorns(bonus)
    (use = use_counters.find { _1.id == bonus.thorns_from_id }) ? track_thorns(use) : 0
  end

  # Thorns it leaves out of a roll with this stat, before any situational ones.
  def bonus_ignored_damage(bonus, stat)
    bonus.ignore == "damage" ? (damage_reasons(stat) & Character::Damage::MARK_AND_HARMS).size : 0
  end

  def bonus_use(bonus)
    use_counters.find { _1.id == bonus.use_id } if bonus.use
  end

  def bonus_ready?(bonus)
    !bonus.use || uses_left(bonus_use(bonus)).positive?
  end

  # The ticked bonuses (ids) plus every automatic one, for this roll: each as
  # [talent, bonus, dice]. Raises if a tick isn't one this stat offers, or
  # spends a use there's none left of.
  def talent_bonuses_rolled(stat, mode, ticked)
    picked_bonuses(talent_bonuses_for(stat), ticked, stat.capitalize)
      .select { _2.applies_to?(mode, stat) }.map { |talent, bonus| [ talent, bonus, bonus_dice(bonus, stat) ] }
  end

  # For a story roll or montage at a roll call: [talent, bonus, dice].
  def call_bonuses_rolled(kind, ticked)
    picked_bonuses(talent_bonuses_for_call(kind), ticked, "a #{kind == "story" ? "story roll" : kind}")
      .map { |talent, bonus| [ talent, bonus, bonus_dice(bonus) ] }
  end

  # How a roll stores them, under the talent's name as this character has it.
  def bonus_records(rolled, ignored: {})
    rolled.map do |talent, bonus, dice|
      { "id" => bonus.id, "name" => talent.name, "dice" => dice, "ignored" => ignored.fetch(bonus.ignore, 0), "counts_as" => bonus.counts_as, "cast" => (true if bonus.cast) }.compact
    end
  end

  private
    def picked_bonuses(offered, ticked, roll_name)
      ticked = Array(ticked).compact_blank.map(&:to_s).uniq
      unknown = ticked - offered.reject { _2.auto? }.map { _2.id }
      raise ArgumentError, "#{name} has no talent bonus #{unknown.first.inspect} for #{roll_name}." if unknown.any?

      offered.select { |_, bonus| bonus.auto? || ticked.include?(bonus.id) }.each do |talent, bonus|
        raise ArgumentError, "No #{bonus_use(bonus).label.downcase} left for #{talent.name}." unless bonus_ready?(bonus)
      end
    end

    def harm_reasons(stat)
      damage_reasons(stat) & Character::Damage::HARMS
    end

    # Offered only when it could change something: a bonus that counts marks
    # or harm needs some, and a talent's use needs the talent to have it.
    def bonus_fits?(bonus, stat)
      if bonus.during == "frenzy" then in_frenzy?
      elsif bonus.harm then harm_reasons(stat).any?
      elsif bonus.per_mark then Grimwild::STATS.any? { marked?(_1) } || damage_thorns(stat).positive?
      elsif bonus.use then bonus_use(bonus).present?
      else true
      end
    end
end
