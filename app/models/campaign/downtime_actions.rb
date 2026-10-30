# Expanded downtime (optional rule, pg. 142): when time passes, the GM picks
# how each character spent it, one action, or two different ones if they sold
# a treasure:
#
# - rest: heal marks, harm, vex and the conditions the GM leaves ticked.
# - plan: a thread for details from that preparation (prep_note), outside the
#   thread cap, lost when time passes again.
# - goal: roll a task pool for a side goal, made the first time (a goal pool,
#   Character::Goals).
# - unwind: a vignette, and take spark.
# - venture: a story roll for how it goes; the GM may reward it.
#
# Only resting heals: the rule replaces downtime's healing (and carousing).
# Talents and talent pools still reset for everyone, and campaign pools roll.
module Campaign::DowntimeActions
  extend ActiveSupport::Concern

  ACTIONS = {
    "rest" => "Rest",
    "plan" => "Plan ahead",
    "goal" => "Pursue a goal",
    "unwind" => "Unwind",
    "venture" => "Venture"
  }.freeze

  # What each action reads as in the log ("Ash rests").
  DONE = {
    "rest" => "rests", "plan" => "plans ahead", "goal" => "pursues a goal",
    "unwind" => "unwinds", "venture" => "ventures"
  }.freeze

  def expanded_downtime?
    optional_rule?(:expanded_downtime)
  end

  private
    # picks: { "character_id" => { "actions" => [...], "plan" => "...", "goal_id" => id or "new",
    #          "goal_name" => "...", "goal_size" => 4, "venture" => "...", "unwind" => "..." } }
    # Returns "Ash rests and plans ahead" lines for the marker.
    def take_downtime_actions!(characters, picks:, cleared:, by:, random:)
      characters.filter_map do |character|
        pick = picks.fetch(character.id.to_s, {})
        actions = (Array(pick["actions"]).map(&:to_s) & ACTIONS.keys).uniq.first(2)
        character.forget_plan
        actions.each { |action| take_downtime_action!(action, character, pick, cleared: cleared.fetch(character.id.to_s, []), by: by, random: random) }
        character.save!
        "#{character.short_name} #{actions.map { DONE[_1] }.to_sentence}" if actions.any?
      end
    end

    def take_downtime_action!(action, character, pick, cleared:, by:, random:)
      case action
      when "rest"
        character.rest(by: by)
        character.conditions = character.conditions.reject.with_index { |_, index| cleared.include?(index) }
      when "plan"
        character.plan_ahead(pick["plan"])
      when "goal"
        character.save!
        character.pursue_goal!(goal_id: pick["goal_id"], name: pick["goal_name"], size: pick["goal_size"], by: by, random: random)
      when "unwind"
        character.settle_spark(take: true)
        vignette = pick["unwind"].to_s.squish.first(200).presence
        Roll.note!(campaign: self, by: by, character: character, text: "#{character.short_name} unwinds#{": #{vignette}" if vignette}.")
      when "venture"
        character.save!
        Roll.story!(campaign: self, by: by, character: character, question: [ "Venture", pick["venture"].to_s.squish.presence ].compact.join(": "), random: random)
      end
    end
end
