# What a player does with a talent from its card: roll what it calls for
# (Talent::Roll, as a roll call for the character), and push yourself (pg.
# 21): use the talent, then mark a stat of your choice.
module Character::TalentActions
  extend ActiveSupport::Concern

  # Spends the roll's thread or talent use, then calls the roll. Anything that
  # stops the call (another one waiting, say) gives them back.
  def call_talent_roll!(key, index, by:)
    talent = talent_entry(key)
    roll = talent.rolls[index.to_i] or raise ArgumentError, "#{talent.name} has no roll like that."
    raise ArgumentError, "Seat #{name} in a campaign to roll at the table." unless campaign && !up_for_grabs?
    raise ArgumentError, "#{name} is #{status}; return them to play to roll." if gone?

    transaction do
      spend_for_roll!(roll)
      question = "#{talent.name}: #{roll.label}"
      if roll.montage?
        RollCall.montage!(campaign: campaign, by: by, characters: [ self ], scene: question, bonus: roll.bonus)
      else
        RollCall.story!(campaign: campaign, by: by, character: self, question: question, odds: roll.odds)
      end
    end
  end

  # Marks the stat (or the harm it turns into), and says so in the log.
  def push!(stat, talent_key:, by:)
    talent = talent_entry(talent_key)
    raise ArgumentError, "#{talent.name} doesn't ask you to push yourself." unless talent.pushes?
    raise ArgumentError, "#{name} is #{status}; return them to play to push." if gone?

    self.changed_by = by
    took = take_mark(stat)
    save!
    Roll.note!(campaign: campaign, by: by, character: self, text: "#{short_name} pushes for #{talent.name} and #{took}.") if campaign
    took
  end

  private
    def spend_for_roll!(roll)
      if roll.thread.positive?
        raise ArgumentError, "#{name} has no thread left to spend." if thread < roll.thread
        update!(thread: thread - roll.thread)
      end
      if (use = use_counters.find { _1.id == roll.use_id })
        raise ArgumentError, "No #{use.label.downcase} left this #{use.per}." unless uses_left(use).positive?
        spend_use!(use.id, spent: uses_spent(use) + 1)
      end
    end
end
