class RollsController < ApplicationController
  # /roll?dice=2&thorns=1&for=Tibbs:+Agility&reasons=marked presets the roller,
  # e.g. when rolling a stat from a character sheet.
  def show
    if params[:dice].present?
      @preset = {
        dice_count: params[:dice].to_i.clamp(1, 8),
        damage_thorns: params[:thorns].to_i.clamp(0, 8),
        for: params[:for].to_s.first(100).presence,
        reasons: params[:reasons].to_s.first(100).presence,
        character: (Current.identity.characters.find_by(id: params[:character_id]) if authenticated?)
      }
    end
  end
end
