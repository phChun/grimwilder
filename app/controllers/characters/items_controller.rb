# A character's important items (Item): the owner and the campaign's GM add,
# change and remove them. The form opens in the sheet's modal
# (shared/_frame_modal).
class Characters::ItemsController < ApplicationController
  include TendedCharacter

  before_action :set_item, only: %i[ edit update destroy ]

  def new
    @item = @character.items.build
  end

  def create
    @item = @character.items.build(item_params)
    if @item.save
      note_to_table "#{@character.name} gains #{@item.name}"
      back_to_item
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @item.update(item_params)
      back_to_item
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @item.destroy!
    refresh_sheet_and_table
    redirect_to character_path(@character, anchor: "arcana"), notice: "#{@item.name} removed."
  end

  private
    def set_item
      @item = @character.items.find(params[:id])
    end

    def item_params
      params.expect(item: [ :name, :description, :counted, :quantity ])
    end

    def back_to_item
      refresh_sheet_and_table
      redirect_to character_path(@character, anchor: "item-#{@item.id}")
    end
end
