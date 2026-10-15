# Roll a stat from the sheet: sends its dice and the thorns from damage to the
# roller, and clears the stat's mark (it only counts for the next roll).
class Characters::RollsController < ApplicationController
  include CharacterScoped

  def create
    stat = params.expect(:stat)
    roll = @character.roll!(stat)

    redirect_to roll_path(
      dice: roll[:dice],
      thorns: roll[:thorns],
      for: "#{@character.name}: #{stat.capitalize}",
      reasons: roll[:reasons].join(", ").presence,
      character_id: @character.id
    )
  rescue ArgumentError
    redirect_to @character, alert: "Pick Brawn, Agility, Wits or Presence."
  end
end
