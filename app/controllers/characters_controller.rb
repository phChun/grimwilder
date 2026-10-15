class CharactersController < ApplicationController
  require_authentication

  before_action :set_character, only: %i[ show edit update destroy ]
  before_action :require_owner, only: %i[ edit update destroy ]

  def index
    @characters = Current.identity.characters.includes(:campaign).ordered
  end

  def show
  end

  def new
    @character = Current.identity.characters.new(path: params[:path].presence || "Fighter", campaign_id: params[:campaign_id])
  end

  def create
    @character = Current.identity.characters.new(character_params)

    if @character.save
      redirect_to @character, notice: "#{@character.name} is ready."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @character.update(character_params)
      redirect_to @character
    else
      render (params[:quick] ? :show : :edit), status: :unprocessable_entity
    end
  end

  def destroy
    @character.destroy
    redirect_to characters_path, notice: "#{@character.name} was deleted."
  end

  private
    def set_character
      @character = Character.visible_to(Current.identity).find(params[:id])
    end

    def require_owner
      head :forbidden unless @character.owned_by?(Current.identity)
    end

    def character_params
      params.require(:character).permit(
        :name, :path, :campaign_id, :level, :xp,
        :brawn, :agility, :wits, :presence, :spark, :thread,
        :marked_brawn, :marked_agility, :marked_wits, :marked_presence, :bloodied, :rattled, :desperate,
        :not_trait, :not_desire, :weapons, :talents, :notes,
        traits: [], desires: [], features: [], weapon_styles: [], arcs: [],
        backgrounds: [ :name, wises: [] ], bonds: [ :to, :bond ]
      ).tap { |permitted| permitted[:campaign_id] = nil if permitted.key?(:campaign_id) && permitted[:campaign_id].blank? }
    end
end
