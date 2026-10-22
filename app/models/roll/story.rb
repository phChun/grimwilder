# Story rolls (pg. 16): luck, or how true a doubtful detail is, read from good
# (perfect) to bad (disaster). Usually 2d; 1d for bad odds, 3d for good, and
# thorns are rare but allowed. Made for a character, it can take spark like any
# roll, and a disaster gives spark (pg. 12).
module Roll::Story
  extend ActiveSupport::Concern

  ODDS = { 1 => "bad odds", 2 => "even odds", 3 => "good odds" }.freeze

  class_methods do
    # rolled: { dice:, thorns: } the player already rolled at a roll call, with
    # their spark already spent (RollCall); otherwise the server rolls here.
    def story!(campaign:, by:, question: nil, odds: 2, thorns: 0, character: nil, spend_spark: 0, rolled: nil, random: Random)
      raise ArgumentError, "Pick 1d, 2d or 3d for the odds." unless ODDS.key?(odds)
      raise ArgumentError, "Thorns go from 0 to #{Character::Rolling::MAX_EXTRA}." unless thorns.in?(0..Character::Rolling::MAX_EXTRA)
      raise ArgumentError, "Only a character can spend spark." if character.nil? && spend_spark != 0
      character&.check_spark_spend!(spend_spark) unless rolled

      result = rolled ? Grimwild::Dice.interpret(rolled[:dice], rolled[:thorns]) : Grimwild::Dice.roll(odds + spend_spark, thorns, random: random)

      transaction do
        gained = character&.settle_spark(spent: rolled ? 0 : spend_spark, take: result.result == "disaster") || false
        character&.save!

        create!(
          campaign: campaign, identity: by, character: character, kind: "story",
          name: character&.name || by.display_name, question: question.to_s.squish.first(200).presence,
          dice: result.dice, thorns: result.thorns, outcome: result.result, critical: result.critical,
          stat_dice: odds, spark_spent: spend_spark, spark_gained: gained
        )
      end
    end
  end

  def odds
    ODDS[stat_dice]
  end
end
