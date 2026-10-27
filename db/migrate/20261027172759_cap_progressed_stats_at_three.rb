# Stat progression raises a stat "to a max of 3" (pg. 175), but the app let
# the progressed stat reach 4. A character at 4 goes back to 3 and has the
# talent slot back, since the +1 bought nothing within the rule; the log says
# so. Data only; nothing to undo.
class CapProgressedStatsAtThree < ActiveRecord::Migration[8.2]
  def up
    Character.where.not(stat_progression: nil).find_each do |character|
      stat = character.stat_progression
      next unless character.public_send(stat) > 3

      character.update_columns(stat => 3, stat_progression: nil)
      next unless character.campaign

      Roll.note!(campaign: character.campaign, by: character.identity, character: character,
        text: "Stat progression goes only to 3: #{character.short_name}'s #{stat.capitalize} is 3 again, and the talent slot is back.")
    end
  end

  def down
  end
end
