# Action and defense rolls from the sheet. The setup folds open on the stat
# card itself; the server rolls, then the sheet shows the result as a toast.
# Rolls of a seated character also land in the campaign's log for the whole
# table.
class Characters::RollsController < ApplicationController
  include CharacterScoped

  def create
    stat = params.expect(:stat)
    @character.roll!(stat, by: Current.identity, mode: params[:mode].presence || "action",
      spend_spark: params[:spark].to_i, help: help(stat), thorns: situational_thorns(stat), assists: assists, bonuses: params[:bonuses],
      assist_bonuses: assist_bonuses, panache: params[:panache].to_i, help_from: params[:help_from])
    redirect_to @character
  rescue ArgumentError => error
    redirect_to @character, alert: error.message
  end

  private
    # The stat card's steppers show totals: dice with the stat's own, thorns
    # with the ones damage adds. The roll takes what's on top of those. (Only
    # for a real stat: Character#stat is a public_send, and roll! checks the
    # name after these run.)
    def help(stat)
      return params[:help].to_i unless params[:dice].present? && Grimwild::STATS.include?(stat)
      params[:dice].to_i - @character.stat(stat)
    end

    def situational_thorns(stat)
      return params[:thorns].to_i unless params[:total_thorns].present? && Grimwild::STATS.include?(stat)
      params[:total_thorns].to_i - @character.damage_thorns(stat)
    end

    # { ally id => talent bonus ids }; the model checks each is that ally's.
    def assist_bonuses
      params.fetch(:assist_bonuses, {}).to_unsafe_h.transform_values { Array(_1).map(&:to_s) }
    end

    # The model checks that every assist is seated alongside this character.
    def assists
      Character.where(id: Array(params[:assists]).compact_blank).to_a
    end
end
