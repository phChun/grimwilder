# Harm and marks on the sheet's Harm card: the owner's or the GM's toggles.
class Characters::DamagesController < ApplicationController
  include CharacterDamage

  HARM_ATTRIBUTES = [ *Character::Damage::HARMS, *Grimwild::STATS.map { "marked_#{_1}" } ].freeze

  def update
    @character.update!(params.expect(character: HARM_ATTRIBUTES))
    back_to_damage
  end
end
