module CharactersHelper
  # A character's owner and their campaign's GM can tick talent uses.
  def can_spend_talent_uses?(character)
    character.owned_by?(Current.identity) ||
      (character.campaign && Current.identity&.membership_in(character.campaign)&.gm?)
  end
end
