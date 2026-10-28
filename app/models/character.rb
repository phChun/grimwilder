# A player character. Owned by an identity; optionally seated in one of that
# identity's campaigns, where the table can see it. The GM can offer one up for
# grabs for a player to pick (Character::Claiming).
class Character < ApplicationRecord
  include Character::Damage, Character::Rolling, Character::Advancement, Character::Talents, Character::TalentSkins, Character::TalentChoices, Character::TalentUses, Character::TalentBonuses, Character::TalentState, Character::StatProgression, Character::BondSpark, Character::Arcana, Character::Sessions, Character::Claiming, Character::Seating, Character::EldritchTalents, Character::TalentActions, Character::Farewell, Character::Oath, Character::RulePools, Character::TableSettings

  STARTING_STAT_TOTAL = 8 # 1 in each stat + 4 points (pg. 47)

  belongs_to :identity
  belongs_to :campaign, optional: true

  normalizes :name, with: ->(value) { value.squish }

  validates :name, presence: true, length: { maximum: 80 }
  validates :path, inclusion: { in: ->(_) { Grimwild.paths.keys } }
  validates(*Grimwild::STATS, numericality: { only_integer: true, in: 1..3 })
  validates :spark, numericality: { only_integer: true, in: 0..Grimwild::MAX_SPARK }
  validates :thread, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: :session_thread }
  validate :starting_stats_add_up, on: :create
  validate :seated_in_own_campaign

  # Fallen and retired characters stay on the campaign page, under the party.
  enum :status, %w[ active fallen retired ].index_by(&:itself), default: "active", validate: true

  scope :ordered, -> { order(:name) }

  # Characters a person may look at: their own, plus those seated in campaigns they belong to.
  scope :visible_to, ->(identity) {
    where(identity: identity).or(where(campaign_id: identity.memberships.select(:campaign_id)))
  }

  # --- details: json columns, cleaned on the way in ---------------------------

  # Each word or phrase typed into the details (a background, wise, trait,
  # feature, weapon style, arc…) is cut to this.
  WORD_LIMIT = 80
  normalizes :not_trait, :not_desire, :weapons, with: ->(value) { value.to_s.squish.first(WORD_LIMIT) }

  def backgrounds=(value)
    super(list(value).filter_map { |background|
      background = background.to_h.stringify_keys
      name = background["name"].to_s.squish.first(WORD_LIMIT)
      wises = words(background["wises"]).first(3)
      { "name" => name, "wises" => wises } if name.present? || wises.any?
    }.first(2))
  end

  %w[ traits desires weapon_styles ].each do |attribute|
    define_method(:"#{attribute}=") { |value| super(words(value).first(2)) }
  end

  def features=(value)
    super(words(value).first(3))
  end

  def arcs=(value)
    super(words(value).first(2))
  end

  # One bond toward each other PC (pg. 23, 47), as many as there are. A bond
  # to someone at the table keeps their character_id (a row left blank is
  # dropped); a bond to anyone else is a name. One per character or name.
  # Who a bond is toward (an NPC's name) and the bond itself are each cut to this.
  BOND_LIMIT = 60

  def bonds=(value)
    super(list(value).filter_map { |bond|
      bond = bond.to_h.stringify_keys
      to, nature = [ bond["to"], bond["bond"] ].map { _1.to_s.squish.first(BOND_LIMIT) }
      id = bond["character_id"].presence&.to_i
      next if id && nature.blank?
      { "to" => to, "bond" => nature, "character_id" => id }.compact if to.present? || nature.present?
    }.uniq { _1["character_id"] || _1["to"].downcase })
  end

  # The other characters at this one's table, each owed a bond.
  def bond_party
    campaign ? campaign.characters.played.active.where.not(id: id).includes(:identity).ordered : Character.none
  end

  # This character's bond toward another: by id, or for one written before
  # bonds knew ids, by their name or short name.
  def bond_for(other)
    bonds.find { _1["character_id"] == other.id } ||
      bonds.find { |bond| bond["character_id"].nil? && [ other.name, other.short_name ].any? { _1.casecmp?(bond["to"].to_s) } }
  end

  # Bonds to anyone not in this party: a character who left, or written in by hand.
  def bonds_beyond(party)
    bonds - party.filter_map { bond_for(_1) }
  end

  def core_talent
    core_talent_entry&.name
  end

  # What the table calls them: a quoted nickname (Gibbletibble "Tibbs"), or the first name.
  def short_name
    name[/["“]([^"”]+)["”]/, 1]&.strip.presence || name.split.first
  end

  def stat(name)
    public_send(name)
  end

  def owned_by?(identity)
    identity_id == identity&.id
  end

  # The owner, or the GM of the campaign this character is seated in: who may
  # tick talent uses and mark harm, marks and conditions on the sheet.
  def tended_by?(identity)
    owned_by?(identity) || (campaign && identity&.membership_in(campaign)&.gm?) || false
  end

  private
    # Rails sends nested form fields as a hash keyed "0", "1", ...
    def list(value)
      value.is_a?(Hash) || value.is_a?(ActionController::Parameters) ? value.to_h.sort_by { |key, _| key.to_i }.map(&:last) : Array(value)
    end

    def words(value)
      list(value).map { _1.to_s.squish.first(WORD_LIMIT) }.compact_blank
    end

    def starting_stats_add_up
      total = Grimwild::STATS.sum { |name| stat(name).to_i }
      unless total == starting_stat_total
        errors.add(:base, "Stats should add up to #{starting_stat_total} (1 in each, plus #{starting_stat_total - 4} points#{" at level 0" if level.to_i.zero?}); they add up to #{total}")
      end
    end

    def seated_in_own_campaign
      if campaign && !identity&.memberships&.exists?(campaign: campaign)
        errors.add(:campaign, "must be one of your campaigns")
      end
    end
end
