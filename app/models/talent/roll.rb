# A roll a talent calls for (config/talents.yml `rolls:`), offered as a button
# on the talent's card: a story roll at some odds (Pact's 3d to wield the
# patron's magic) or a montage (According to Plan's flashback). It may spend a
# thread or one of the talent's uses first, and a montage may roll extra dice
# (Scout Ahead's 3d). With `rising`, a story roll takes +1t for each time its
# use was ticked before this one (Mischief Maker's overloads, clearing each
# session). Rolled as a roll call for the character (RollCall). An `action`
# roll is a fixed number of `dice` the server rolls right away, logged under
# `as` in place of a stat (Animal Companion's 3d for a trick, "3d Trick").
class Talent::Roll < Data.define(:talent_key, :index, :kind, :label, :odds, :bonus, :thread, :use, :rising, :dice, :as)
  KINDS = %w[ story montage action ].freeze

  def self.from(talent_key, index, attributes)
    attributes = attributes.transform_keys(&:to_sym)
    new(talent_key: talent_key, index: index, kind: attributes.fetch(:kind), label: attributes.fetch(:label),
      odds: attributes[:odds] || 2, bonus: attributes[:bonus] || 0, thread: attributes[:thread] || 0, use: attributes[:use], rising: attributes[:rising] || false,
      dice: attributes[:dice], as: attributes[:as])
  end

  def story?
    kind == "story"
  end

  def montage?
    kind == "montage"
  end

  def action?
    kind == "action"
  end

  # What the roll uses up, for the button's hint: "spends 1 thread".
  def cost
    [ ("#{thread} thread" if thread.positive?), ("a use" if use) ].compact.to_sentence.presence
  end

  # "3d story roll", "3d montage".
  def dice_label
    if action? then "#{dice}d roll"
    elsif montage? then "#{Roll::Montage::DICE + bonus}d montage"
    else "#{odds}d story roll"
    end
  end

  # The talent use it ticks: "weasel/weasel".
  def use_id
    "#{talent_key}/#{use}" if use
  end
end
