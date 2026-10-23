class CharactersController < ApplicationController
  require_authentication

  before_action :set_character, only: %i[ show edit update destroy ]
  before_action :require_owner, only: %i[ edit update destroy ]

  def index
    @characters = Current.identity.characters.includes(:campaign).ordered
    @campaigns = Current.identity.campaigns.order(:name)
  end

  # The sheet is where a player plays: rolls fold open on the stat cards, and
  # a seated character's sheet also shows the table's roll log and chat.
  def show
    load_play
  end

  def new
    @character = Current.identity.characters.new(path: params[:path].presence || "Fighter", campaign_id: params[:campaign_id], up_for_grabs: params[:up_for_grabs] == "1")
  end

  def create
    @character = Current.identity.characters.new(character_params)

    if @character.save
      # Next step: their first talent (pg. 46), alongside the path's core talent.
      redirect_to new_character_talent_path(@character), notice: "#{@character.name} is ready. Now choose a first talent."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    @character.changed_by = Current.identity
    if @character.update(character_params)
      redirect_to @character
    else
      load_play if params[:quick]
      render (params[:quick] ? :show : :edit), status: :unprocessable_entity
    end
  end

  def destroy
    @character.destroy
    redirect_to characters_path, notice: "#{@character.name} was deleted."
  end

  private
    # For a seated character, the table around the sheet.
    def load_play
      @allies = @character.campaign ? @character.campaign.characters.played.active.excluding(@character).ordered : []

      if (campaign = @character.campaign)
        @membership = Current.identity.memberships.find_by!(campaign: campaign)
        @feed = TableFeed.new(campaign, @membership)
        @speakers = Current.identity.characters.where(campaign: campaign).played.active.ordered
      end
    end

    def set_character
      @character = Character.visible_to(Current.identity).find(params[:id])
    end

    def require_owner
      head :forbidden unless @character.owned_by?(Current.identity)
    end

    def character_params
      params.require(:character).permit(
        :name, :path, :campaign_id, :status, :farewell, :up_for_grabs, :level, :xp,
        :brawn, :agility, :wits, :presence, :spark, :thread,
        :marked_brawn, :marked_agility, :marked_wits, :marked_presence, :bloodied, :rattled, :desperate,
        :not_trait, :not_desire, :weapons, :talents, :notes,
        traits: [], desires: [], features: [], weapon_styles: [], arcs: [],
        backgrounds: [ :name, wises: [] ], bonds: [ :to, :bond, :character_id ]
      ).tap { |permitted| permitted[:campaign_id] = nil if permitted.key?(:campaign_id) && permitted[:campaign_id].blank? }
    end
end
