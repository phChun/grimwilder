module RollCallsHelper
  # What each seat rolls, under the title: "2d (even odds) vs 1t".
  def roll_call_hint(call)
    case call.kind
    when "story" then "#{call.odds}d (#{Roll::ODDS[call.odds]})#{" vs #{call.thorns}t" if call.thorns.positive?}, plus any spark. From good (perfect) to bad (disaster)."
    when "montage" then "Each rolls 2d, plus any spark. The best result is the scene's outcome."
    when "quarrel" then "Each side rolls 2d, plus any spark; assists roll 1d. The highest die wins, and everyone in it takes spark."
    end
  end

  # On the pill while the modal is hidden: "your roll", "waiting on Bram".
  def roll_call_waiting_line(call)
    mine = call.waiting.any? { call.character_for(_1)&.owned_by?(Current.identity) }
    mine ? "your roll" : "waiting on #{call.waiting.pluck("name").to_sentence}"
  end

  # A seat's d6s, the highest lit, then a story roll's thorns.
  def roll_call_dice_tags(seat)
    top = seat["dice"].index(seat["dice"].max)
    tags = seat["dice"].map.with_index { |value, index| die_tag(value, size: 32, state: (:highest if index == top)) }
    tags += seat["thorns"].map { die_tag(_1, kind: "d8", size: 32) }
    safe_join(tags)
  end
end
