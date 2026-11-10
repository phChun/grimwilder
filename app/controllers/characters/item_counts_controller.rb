# Counting an important item up or down from the sheet: one more (by=1) or
# one fewer (by=-1).
class Characters::ItemCountsController < ApplicationController
  include TendedCharacter

  before_action :refuse_when_campaign_archived, :set_item

  def update
    @item.count_by!(params[:by].to_i.clamp(-1, 1))
    refresh_sheet_and_table
    redirect_to character_path(@character, anchor: "item-#{@item.id}")
  end

  private
    def set_item
      @item = @character.items.where(counted: true).find(params[:item_id])
    end
end
