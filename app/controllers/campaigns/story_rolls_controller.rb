# Story rolls from the Rolls fold. For a character, it's a roll call: that
# character's player rolls it (RollCall). The GM can call on anyone at the
# table, a player on their own characters. For no one in particular (the GM
# testing luck, say) it's rolled straight away.
class Campaigns::StoryRollsController < ApplicationController
  include CampaignScoped, StoryRollParams

  def create
    if (character = called_character)
      RollCall.story!(campaign: Current.campaign, by: Current.identity, character: character, **story_roll_options)
      back_to_table(anchor: "rolls")
    else
      Roll.story!(campaign: Current.campaign, by: Current.identity, **story_roll_options)
      back_to_table(anchor: "roll-log")
    end
  rescue ArgumentError => error
    back_to_table(anchor: "rolls", alert: error.message)
  end

  private
    def called_character
      return if params[:character_id].blank?

      characters = Current.campaign.characters.played
      characters = characters.where(identity: Current.identity) unless gm?
      characters.find(params[:character_id])
    end
end
