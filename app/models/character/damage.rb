# Marks, harm and conditions (pg. 27–29), and the thorns they add to rolls.
module Character::Damage
  extend ActiveSupport::Concern

  HARMS = %w[ bloodied rattled desperate ].freeze
  # "4d poisoned": a condition that's also a timer pool (pg. 29).
  CONDITION_POOL = /\A(\d+)d\s+(\S.*)\z/i
  # Pools run 1–20 dice (Pool#starting_size), and so do condition pools.
  CONDITION_MAX_DICE = 20

  included do
    # Whoever is changing marks, harm or conditions right now. Callers set it
    # (the sheet, a roll, a rest), and it's recorded with what changed.
    attr_accessor :changed_by

    belongs_to :harm_changed_by, class_name: "Identity", optional: true
    before_save :note_harm_change, if: -> { changed_by && harm_changing? }
  end

  def marked?(stat)
    public_send(:"marked_#{stat}")
  end

  # +1t for a mark on the stat, +1t for bloodied (Brawn, Agility) or rattled
  # (Wits, Presence), and +1t on every roll while desperate.
  def damage_thorns(stat)
    stat = stat.to_s
    thorns = 0
    thorns += 1 if marked?(stat)
    thorns += 1 if bloodied? && Grimwild::PHYSICAL_STATS.include?(stat)
    thorns += 1 if rattled? && Grimwild::MENTAL_STATS.include?(stat)
    thorns += 1 if desperate?
    thorns
  end

  def damage_reasons(stat)
    stat = stat.to_s
    [
      ("marked" if marked?(stat)),
      ("bloodied" if bloodied? && Grimwild::PHYSICAL_STATS.include?(stat)),
      ("rattled" if rattled? && Grimwild::MENTAL_STATS.include?(stat)),
      ("desperate" if desperate?)
    ].compact
  end

  # Conditions are { "name", "lasts" }: lasts "scene" for short-term ones that
  # clear after a scene (pg. 29), nil for ordinary ones.
  CONDITION_LASTS = %w[ scene ].freeze

  def conditions=(value)
    super(Array(value).filter_map do |condition|
      condition = condition.is_a?(Hash) ? condition.stringify_keys : { "name" => condition }
      name = condition["name"].to_s.squish.first(80)
      { "name" => name, "lasts" => condition["lasts"].presence_in(CONDITION_LASTS) } if name.present?
    end)
  end

  # Taking a mark (pg. 27), as when pushing yourself: a stat already marked
  # takes its harm instead (bloodied for Brawn and Agility, rattled for Wits
  # and Presence); that harm a second time makes you desperate, and harm while
  # desperate drops you, which the sheet doesn't track. Doesn't save. Returns
  # what happened: "marks Brawn", "is bloodied", "is desperate", "is dropped".
  def take_mark(stat)
    stat = stat.to_s
    raise ArgumentError, "Pick Brawn, Agility, Wits or Presence." unless Grimwild::STATS.include?(stat)
    outcome = mark_would_be(stat)
    case outcome
    when "mark" then public_send(:"marked_#{stat}=", true)
    when "dropped" then nil
    else public_send(:"#{outcome}=", true)
    end
    outcome == "mark" ? "marks #{stat.capitalize}" : "is #{outcome}"
  end

  # What taking a mark on this stat would do, for the button: "mark", "bloodied"…
  def mark_would_be(stat)
    return "mark" unless marked?(stat)

    harm = Grimwild::PHYSICAL_STATS.include?(stat.to_s) ? "bloodied" : "rattled"
    !public_send(harm) ? harm : (desperate? ? "dropped" : "desperate")
  end

  # A significant rest (pg. 30) clears all marks and harm. Doesn't save.
  def rest(by: nil)
    self.changed_by = by if by
    assign_attributes(Grimwild::STATS.to_h { [ "marked_#{_1}", false ] }.merge(bloodied: false, rattled: false, desperate: false))
  end

  def rest!(by: nil)
    rest(by: by)
    save!
  end

  # The last change someone other than the owner made: "GM cleared Bloodied".
  def harm_changed_by_someone_else?
    harm_changed_by_id.present? && harm_changed_by_id != identity_id && harm_change.present?
  end

  # [size, name] for a condition that's a pool ("4d poisoned"), else nil.
  def condition_pool(condition)
    match = CONDITION_POOL.match(condition["name"])
    [ match[1].to_i, match[2] ] if match
  end

  # Rolls a condition's pool the way a pool rolls (pg. 18): every 1–3 drops,
  # and at 0d it has run its course (the condition stays until it's cleared).
  # The roll goes in the table's log like any pool roll.
  def roll_condition!(index, by:, random: Random)
    condition = conditions.fetch(index.to_i) { raise ArgumentError, "That condition is gone." }
    size, label = condition_pool(condition)
    raise ArgumentError, "#{condition["name"]} isn't a pool to roll." unless size&.positive?

    dice = Array.new(size) { random.rand(1..6) }
    kept = dice.count { _1 >= 4 }

    transaction do
      self.changed_by = by
      update!(conditions: conditions.each_with_index.map { |entry, i| i == index.to_i ? entry.merge("name" => "#{kept}d #{label}") : entry })
      rolls.create!(campaign: campaign, identity: by, kind: "pool", name: "#{name}: #{label}", dice: dice,
        pool_action: "rolled", dropped: size - kept, remaining: kept)
    end
  end

  # dice: makes it a pool ("4d poisoned"), unless the name already is one.
  def add_condition!(name, lasts: nil, dice: nil)
    name = name.to_s.squish
    raise ArgumentError, "Name the condition to add it." if name.empty?

    dice = dice.to_i.clamp(0, CONDITION_MAX_DICE)
    name = "#{dice}d #{name}" if dice.positive? && name.present? && !name.match?(CONDITION_POOL)
    update!(conditions: conditions + [ { "name" => name, "lasts" => lasts } ])
  end

  def remove_condition!(index)
    clear_conditions!([ index.to_i ])
  end

  def clear_conditions!(indexes)
    update!(conditions: conditions.reject.with_index { |_, i| indexes.include?(i) })
  end

  # [index, condition] for each "clears after scene" condition.
  def scene_conditions
    conditions.each_with_index.filter_map { |condition, index| [ index, condition ] if condition["lasts"] == "scene" }
  end

  private
    def harm_changing?
      HARMS.any? { will_save_change_to_attribute?(_1) } || Grimwild::STATS.any? { will_save_change_to_attribute?("marked_#{_1}") } ||
        will_save_change_to_conditions?
    end

    def note_harm_change
      self.harm_change = harm_change_summary
      self.harm_changed_by = changed_by
      self.harm_changed_at = Time.current
    end

    # "marked Bloodied", "cleared Bloodied and the Agility mark", "added 4d poisoned"
    def harm_change_summary
      marked, cleared = [], []

      HARMS.each do |harm|
        next unless will_save_change_to_attribute?(harm)
        (public_send(harm) ? marked : cleared) << harm.capitalize
      end
      Grimwild::STATS.each do |stat|
        next unless will_save_change_to_attribute?("marked_#{stat}")
        marked?(stat) ? marked << stat.capitalize : cleared << "the #{stat.capitalize} mark"
      end

      if will_save_change_to_conditions?
        before, after = conditions_change_to_be_saved.map { |list| Array(list).pluck("name") }
        added, removed = after - before, before - after
        rolled = added.size == 1 && removed.size == 1 && added.first.sub(CONDITION_POOL, '\\2') == removed.first.sub(CONDITION_POOL, '\\2')
        if rolled
          changed = "rolled #{removed.first}: #{added.first[/\A\d+d/]} left"
        else
          added_part = "added #{added.to_sentence}" if added.any?
          cleared.concat(removed)
        end
      end

      [ ("marked #{marked.to_sentence}" if marked.any?), ("cleared #{cleared.to_sentence}" if cleared.any?), added_part, changed ]
        .compact.join(", ").presence
    end
end
