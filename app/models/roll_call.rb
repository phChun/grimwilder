# A story roll, montage or quarrel that waits for its players to roll their
# own dice. Whoever calls it picks who's in it; each player then picks their
# spark and rolls (spark is spent right then, before the roll, pg. 12), and
# the GM can roll for anyone still waiting (with no spark: only a character's
# own player spends it). Once every seat has rolled, the call becomes the
# usual Roll in the log, built from the dice already rolled.
#
# Everyone in it, the GM and the caller see it as a modal (roll_calls/_call)
# on any campaign page; it updates live over [campaign, :live]. One open call
# per campaign at a time.
#
# Each seat: { "character_id", "name", "player", "lead_id" (a quarrel helper's
# side), "dice", "thorns" (a story roll's d8s), "spark", "rolled_by" }; dice
# is nil until that seat rolls.
class RollCall < ApplicationRecord
  belongs_to :campaign
  belongs_to :identity
  belongs_to :roll, optional: true

  enum :kind, %w[ story montage quarrel ].index_by(&:itself), validate: true
  enum :status, %w[ open done cancelled ].index_by(&:itself), validate: true

  # A finished call keeps showing its result to the people in it for this long.
  RESULT_SHOWS_FOR = 2.minutes

  after_commit :broadcast_to_table

  class << self
    def story!(campaign:, by:, character:, question: nil, odds: 2, thorns: 0)
      raise ArgumentError, "Pick 1d, 2d or 3d for the odds." unless Roll::ODDS.key?(odds)
      raise ArgumentError, "Thorns go from 0 to #{Character::Rolling::MAX_EXTRA}." unless thorns.in?(0..Character::Rolling::MAX_EXTRA)

      call!(campaign, by, kind: "story", question: question, odds: odds, thorns: thorns, seats: [ seat(character) ])
    end

    def montage!(campaign:, by:, characters:, scene: nil)
      raise ArgumentError, "Pick who takes part in the montage." if characters.empty?

      call!(campaign, by, kind: "montage", question: scene, seats: characters.map { seat(_1) })
    end

    # sides: [{ character:, helpers: [characters] }, ...]
    def quarrel!(campaign:, by:, sides:, stakes: nil)
      raise ArgumentError, "A quarrel needs at least two sides." if sides.size < 2

      seats = sides.flat_map do |side|
        [ seat(side[:character]), *side[:helpers].map { seat(_1, lead: side[:character]) } ]
      end
      call!(campaign, by, kind: "quarrel", question: stakes, seats: seats)
    end

    # What this member sees: the open call they're part of, or one that just
    # finished, for a little while.
    def showing_for(campaign, membership)
      call = where(campaign: campaign).where(status: "open").or(where(campaign: campaign, status: "done", updated_at: RESULT_SHOWS_FOR.ago..))
        .order(updated_at: :desc).first
      call if call&.involves?(membership)
    end

    private
      def call!(campaign, by, seats:, **attributes)
        ids = seats.pluck("character_id")
        raise ArgumentError, "Each character can only take one part." unless ids.uniq.size == ids.size
        raise ArgumentError, "Everyone in it must be seated in #{campaign.name}." unless campaign.characters.played.where(id: ids).count == ids.size
        if (waiting = campaign.roll_calls.open.first)
          raise ArgumentError, "Finish or cancel the #{waiting.title.downcase} that's waiting first."
        end

        create!(campaign: campaign, identity: by, seats: seats, **attributes)
      end

      def seat(character, lead: nil)
        { "character_id" => character.id, "name" => character.name, "player" => character.identity.display_name,
          "lead_id" => lead&.id, "dice" => nil, "thorns" => [], "spark" => 0, "rolled_by" => nil }
      end
  end

  def title
    { "story" => "Story roll", "montage" => "Montage", "quarrel" => "Quarrel" }.fetch(kind)
  end

  def involves?(membership)
    return false unless membership
    membership.gm? || identity_id == membership.identity_id || characters.any? { _1.owned_by?(membership.identity) }
  end

  # Loaded once per lock: with_lock reloads the call, and that drops them, so
  # spark spent since is never undone by a stale copy.
  def reload(...)
    @characters = nil
    super
  end

  def characters
    @characters ||= campaign.characters.where(id: seats.pluck("character_id")).includes(:identity).index_by(&:id).values_at(*seats.pluck("character_id")).compact
  end

  def character_for(seat)
    characters.find { _1.id == seat["character_id"] }
  end

  def waiting
    seats.reject { _1["dice"] }
  end

  def assist?(seat)
    seat["lead_id"].present?
  end

  def lead_name(seat)
    seats.find { _1["character_id"] == seat["lead_id"] }&.dig("name")
  end

  # Before spark: the odds for a story roll, 1d to assist, else 2d.
  def base_dice(seat)
    if story? then odds
    elsif assist?(seat) then 1
    else Roll::Quarrel::DICE
    end
  end

  def may_roll?(seat, identity)
    open? && seat["dice"].nil? && (character_for(seat)&.owned_by?(identity) || gm?(identity))
  end

  def may_cancel?(identity)
    open? && (identity_id == identity&.id || gm?(identity))
  end

  # One seat rolls. Spark is the player's to spend, and assists roll 1d alone.
  def roll!(character, by:, spark: 0, random: Random)
    with_lock do
      seat = seats.find { _1["character_id"] == character.id }
      raise ArgumentError, "That roll is over." unless open?
      raise ArgumentError, "#{character.name} isn't in this roll." unless seat
      raise ArgumentError, "#{character.name} already rolled." if seat["dice"]
      raise ArgumentError, "Only #{character.name}'s player or the GM can roll for them." unless may_roll?(seat, by)

      roll_seat(seat, character, by: by, spark: spark.to_i, random: random)
      finish! if waiting.empty?
    end
  end

  # The GM rolls for everyone still waiting, without spending their spark.
  def roll_everyone!(by:, random: Random)
    with_lock do
      raise ArgumentError, "That roll is over." unless open?
      raise ArgumentError, "Only the GM can roll for everyone." unless gm?(by)

      waiting.each { |seat| roll_seat(seat, character_for(seat), by: by, spark: 0, random: random) }
      finish!
    end
  end

  # Called off: any spark already spent goes back.
  def cancel!(by:)
    with_lock do
      raise ArgumentError, "Only the GM or whoever called it can cancel it." unless may_cancel?(by)

      seats.select { _1["spark"].positive? }.each do |seat|
        character_for(seat)&.then { _1.update!(spark: [ _1.spark + seat["spark"], Grimwild::MAX_SPARK ].min) }
      end
      update!(status: "cancelled")
    end
  end

  private
    def gm?(identity)
      identity&.membership_in(campaign)&.gm? || false
    end

    def roll_seat(seat, character, by:, spark:, random:)
      raise ArgumentError, "#{character.name} is no longer at the table." unless character
      raise ArgumentError, "Only #{character.name}'s player can spend their spark." if spark.positive? && !character.owned_by?(by)
      raise ArgumentError, "An assist rolls 1d, without spark." if spark.positive? && assist?(seat)
      character.check_spark_spend!(spark)

      character.settle_spark(spent: spark)
      character.save!
      seat.merge!(
        "dice" => Array.new(base_dice(seat) + spark) { random.rand(1..6) },
        "thorns" => story? ? Array.new(thorns) { random.rand(1..8) } : [],
        "spark" => spark, "rolled_by" => (by.display_name unless character.owned_by?(by))
      )
      self.seats = seats.map(&:dup)
      save!
    end

    # The characters' spark changed as each seat rolled, so load them again.
    def finish!
      @characters = nil
      update!(status: "done", roll: resolved_roll)
    end

    def resolved_roll
      case kind
      when "story"
        seat = seats.first
        Roll.story!(campaign: campaign, by: identity, question: question, odds: odds, thorns: thorns, character: character_for(seat),
          spend_spark: seat["spark"], rolled: { dice: seat["dice"], thorns: seat["thorns"] })
      when "montage"
        Roll.montage!(campaign: campaign, by: identity, scene: question,
          participants: seats.map { { character: character_for(_1), spend_spark: _1["spark"], dice: _1["dice"] } })
      when "quarrel"
        sides = seats.reject { assist?(_1) }.map do |lead|
          helpers = seats.select { _1["lead_id"] == lead["character_id"] }
          { character: character_for(lead), spend_spark: lead["spark"], dice: lead["dice"],
            helpers: helpers.map { character_for(_1) }, helper_dice: helpers.map { _1["dice"].first } }
        end
        Roll.quarrel!(campaign: campaign, by: identity, stakes: question, sides: sides)
      end
    end

    # Each viewer's modal is different (your own Roll button, the GM's
    # overrides), so the stream only swaps in a frame that loads each
    # viewer's own copy.
    # It updates the permanent slot rather than replacing it: Turbo puts a
    # permanent element in a stream back the way it was, so the new frame
    # would never land. Pages that offer a finished roll (ending a scene
    # offers its montage) follow [campaign, :roll_calls] for a refresh.
    # Through StreamsChannel, as the model's own helper would pass the call in
    # as a local the frame doesn't take.
    def broadcast_to_table
      Turbo::StreamsChannel.broadcast_update_later_to campaign, :live, target: campaign.roll_call_slot_id, partial: "roll_calls/frame", locals: { campaign: campaign, version: (updated_at.to_f * 1000).to_i }
      Turbo::StreamsChannel.broadcast_refresh_later_to campaign, :roll_calls if done?
    end
end
