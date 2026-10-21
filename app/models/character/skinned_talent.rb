# A talent as this character has it: the book's Talent, with the character's
# re-skinned name, summary or text in front (Character::TalentSkins).
class Character::SkinnedTalent < SimpleDelegator
  attr_reader :skin

  def initialize(talent, skin)
    super(talent)
    @skin = skin.to_h
  end

  def book
    __getobj__
  end

  def skinned?
    skin.any?
  end

  def name
    skin["name"].presence || book.name
  end

  def renamed?
    skin["name"].present?
  end

  def summary
    skin["summary"].presence || book.summary
  end

  # The player's own text, if they wrote one; the book's text is still shown.
  def custom_paragraphs
    skin["text"].to_s.split(/\n{2,}/).map(&:strip).compact_blank
  end
end
