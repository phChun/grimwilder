# Story rolls from the GM's Rolls fold. For a character, it's a roll call:
# that character's player rolls it (RollCall). For no one in particular (the
# GM testing luck, say) it's rolled straight away, and the GM can keep it to
# themselves (gm_only: only the GM's log shows it). Only the GM calls for
# rolls; a player's talent rolls are their own (Characters::TalentRollsController).
class Campaigns::StoryRollsController < ApplicationController
  include CampaignScoped, StoryRollParams
  before_action :refuse_when_on_hold

  before_action :require_gm

  def create
    if (character = called_character)
      RollCall.story!(campaign: Current.campaign, by: Current.identity, character: character, assists: assists(character), **story_roll_options)
      back_to_table(anchor: "rolls")
    else
      Roll.story!(campaign: Current.campaign, by: Current.identity, gm_only: params[:gm_only] == "1", **story_roll_options)
      back_to_table(anchor: "roll-log")
    end
  rescue ArgumentError => error
    back_to_table(anchor: "rolls", alert: error.message)
  end

  private
    # Anyone else seated at the table can assist (pg. 15); they roll their own 1d.
    def assists(character)
      Current.campaign.characters.played.active.where(id: Array(params[:assists]).compact_blank).where.not(id: character.id).to_a
    end

    def called_character
      return if params[:character_id].blank?

      characters = Current.campaign.characters.played.active
      characters = characters.where(identity: Current.identity) unless gm?
      characters.find(params[:character_id])
    end
end
