# What a talent keeps between rolls (Character::TalentState), from its card:
# Herbalism's herb names, Quarry's designations, entering and leaving a
# frenzy, Magus's enchantment, Oathsworn's tenets and Affirmation, Monster
# Menagerie's creature. The owner changes it.
class Characters::TalentStatesController < ApplicationController
  include CharacterScoped

  before_action :refuse_when_campaign_done

  def update
    case params.expect(:change)
    when "herbs" then @character.set_herbs!(params[:herbs])
    when "quarry" then @character.designate_quarry!(params[:name], by: Current.identity)
    when "frenzy" then @character.enter_frenzy!(by: Current.identity, free: params[:free] == "1")
    when "calm" then @character.leave_frenzy!(by: Current.identity)
    when "enchant" then @character.enchant_weapon!(params[:trait], by: Current.identity)
    when "disenchant" then @character.end_enchantment!(by: Current.identity)
    when "violate" then @character.violate_tenet!(params[:tenet], by: Current.identity)
    when "atone" then @character.atone_tenet!(params[:tenet], by: Current.identity)
    when "affirm" then @character.affirm!(@character.campaign.characters.played.active.find(params[:ally_id]), by: Current.identity)
    when "answer" then @character.answer_with!(params[:creature], by: Current.identity)
    else raise ArgumentError, "That's not something #{@character.short_name}'s talents keep track of."
    end
    @character.campaign&.broadcast_table_refresh
    redirect_to character_path(@character, anchor: "talent-#{params[:talent_id]}")
  rescue ArgumentError => error
    redirect_to character_path(@character, anchor: "talent-#{params[:talent_id]}"), alert: error.message
  end
end
