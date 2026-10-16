# Quarrels (pg. 23): when PCs are at odds, each side rolls 2d (spark allowed,
# talents not) and the highest die wins (5 beats 4). Allies can assist, each
# rolling 1d of their own (pg. 13); others can join at 2d as another side. On a
# tie, compromise or keep quarreling. Everyone who took part takes spark.
module Roll::Quarrel
  extend ActiveSupport::Concern

  DICE = 2

  class_methods do
    # sides: [{ character:, spend_spark: 0, helpers: [characters] }, ...]
    def quarrel!(campaign:, by:, sides:, stakes: nil, random: Random)
      everyone = sides.flat_map { |side| [ side[:character], *side[:helpers] ] }
      raise ArgumentError, "A quarrel needs at least two sides." if sides.size < 2
      raise ArgumentError, "Each character can only take one part." unless everyone.uniq.size == everyone.size
      raise ArgumentError, "Everyone in a quarrel must be seated in #{campaign.name}." unless everyone.all? { _1.campaign_id == campaign.id }
      sides.each { |side| side[:character].check_spark_spend!(side[:spend_spark].to_i) }

      rolled = sides.map do |side|
        spent = side[:spend_spark].to_i
        {
          lead: side[:character], spent: spent, dice: Array.new(DICE + spent) { random.rand(1..6) },
          helpers: side[:helpers].map { |helper| { character: helper, die: random.rand(1..6) } }
        }
      end

      tops = rolled.map { |side| (side[:dice] + side[:helpers].pluck(:die)).max }
      leaders = rolled.select.with_index { |_, index| tops[index] == tops.max }

      transaction do
        rolled.each do |side|
          side[:gained] = side[:lead].settle_spark(spent: side[:spent], take: true)
          side[:helpers].each { |helper| helper[:gained] = helper[:character].settle_spark(take: true) }
          [ side[:lead], *side[:helpers].pluck(:character) ].each(&:save!)
        end

        create!(
          campaign: campaign, identity: by, kind: "quarrel", name: rolled.map { _1[:lead].name }.join(" vs "),
          question: stakes.to_s.squish.first(200).presence, winner: (leaders.first[:lead].name if leaders.one?),
          spark_spent: rolled.sum { _1[:spent] }, sides: rolled.map { |side| side_record(side) }
        )
      end
    end

    private
      def side_record(side)
        {
          "character_id" => side[:lead].id, "name" => side[:lead].name, "dice" => side[:dice],
          "spark_spent" => side[:spent], "spark_gained" => side[:gained],
          "helpers" => side[:helpers].map { |helper|
            { "character_id" => helper[:character].id, "name" => helper[:character].name, "die" => helper[:die], "spark_gained" => helper[:gained] }
          }
        }
      end
  end

  def tie?
    quarrel? && winner.nil?
  end

  # Everyone who took part, with whether they took spark (they may hold 2 already).
  def quarrelers
    sides.flat_map { |side| [ side, *side["helpers"] ] }
  end
end
