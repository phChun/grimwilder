# Montage rolls (pg. 16): zoom out over a stretch of the story. Everyone taking
# part makes a 2d action roll (spark allowed), and the highest result is the
# outcome for the whole scene. Zoom back in on unlikely or interesting results.
module Roll::Montage
  extend ActiveSupport::Concern

  DICE = 2

  class_methods do
    # participants: [{ character:, spend_spark: 0, dice: nil, talent_bonuses: [] }, ...];
    # dice the player already rolled at a roll call, with the spark already
    # spent and any talent dice in.
    def montage!(campaign:, by:, participants:, scene: nil, random: Random)
      characters = participants.pluck(:character)
      raise ArgumentError, "Pick who takes part in the montage." if participants.empty?
      raise ArgumentError, "Each character can only roll once." unless characters.uniq.size == characters.size
      raise ArgumentError, "Everyone in a montage must be seated in #{campaign.name}." unless characters.all? { _1.campaign_id == campaign.id }
      participants.each { |participant| participant[:character].check_spark_spend!(participant[:spend_spark].to_i) unless participant[:dice] }

      rolled = participants.map do |participant|
        spent = participant[:spend_spark].to_i
        result = participant[:dice] ? Grimwild::Dice.interpret(participant[:dice]) : Grimwild::Dice.roll(DICE + spent, 0, random: random)
        { character: participant[:character], spent: spent, paid: participant[:dice].present?, result: result, talent_bonuses: Array(participant[:talent_bonuses]) }
      end
      best = rolled.min_by { Grimwild::Dice::RESULTS.index(_1[:result].result) }[:result]

      transaction do
        rolled.each do |side|
          side[:gained] = side[:character].settle_spark(spent: side[:paid] ? 0 : side[:spent], take: side[:result].result == "disaster")
          side[:character].save!
        end

        create!(
          campaign: campaign, identity: by, kind: "montage", name: characters.map(&:name).to_sentence,
          question: scene.to_s.squish.first(200).presence, outcome: best.result,
          spark_spent: rolled.sum { _1[:spent] }, sides: rolled.map { |side| side_result(side) }
        )
      end
    end

    private
      def side_result(side)
        {
          "character_id" => side[:character].id, "name" => side[:character].name, "dice" => side[:result].dice,
          "outcome" => side[:result].result, "critical" => side[:result].critical,
          "spark_spent" => side[:spent], "spark_gained" => side[:gained], "talent_bonuses" => side[:talent_bonuses], "helpers" => []
        }
      end
  end
end
