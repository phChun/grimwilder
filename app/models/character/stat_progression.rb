# The optional stat progression rule (pg. 175): once, a character can give up
# one of their chosen talents for +1 to a stat, to a max of 3, and they have
# room for one talent fewer (Character::Talents). Taking it back gives the
# talent slot back.
module Character::StatProgression
  extend ActiveSupport::Concern

  included do
    validates :stat_progression, inclusion: { in: Grimwild::STATS }, allow_nil: true
  end

  def stat_progressed?
    stat_progression.present?
  end

  # Room for it: not taken yet, a talent slot free to give up, the stat below 3.
  def can_progress_stat?(stat)
    !stat_progressed? && rule_allows?(:stat_progression) && talents_to_choose.positive? && Grimwild::STATS.include?(stat.to_s) && self.stat(stat) < 3
  end

  def progress_stat!(stat, by:)
    raise ArgumentError, "#{short_name} can give up a talent for a stat once, with a talent slot free." unless can_progress_stat?(stat)

    update!(stat_progression: stat.to_s, stat.to_s => self.stat(stat) + 1)
    Roll.note!(campaign: campaign, by: by, character: self, text: "#{short_name} gives up a talent for +1 #{stat.to_s.capitalize}.") if campaign
  end

  def undo_stat_progression!
    raise ArgumentError, "#{short_name} hasn't given up a talent for a stat." unless stat_progressed?
    # Taking it back frees one slot; the sheet must still fit (Talented's extras count).
    raise ArgumentError, "Remove a talent first: #{short_name} is at the most for level #{level}." if talent_keys.size > expected_talent_count + 1
    raise ArgumentError, "#{stat_progression.capitalize} would drop below 1." if stat(stat_progression) <= 1

    update!(stat_progression => self.stat(stat_progression) - 1, stat_progression: nil)
  end
end
