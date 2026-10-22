# A player character. Owned by an identity; optionally seated in one of that
# identity's campaigns, where the table can see it. The GM can offer one up for
# grabs for a player to pick (Character::Claiming).
class Character < ApplicationRecord
  include Character::Damage, Character::Rolling, Character::Advancement, Character::Talents, Character::TalentSkins, Character::TalentUses, Character::Sessions, Character::Claiming, Character::Seating

  STARTING_STAT_TOTAL = 8 # 1 in each stat + 4 points (pg. 46)

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

  def backgrounds=(value)
    super(list(value).filter_map { |background|
      background = background.to_h.stringify_keys
      name = background["name"].to_s.squish
      wises = list(background["wises"]).map { _1.to_s.squish }.compact_blank.first(3)
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

  def bonds=(value)
    super(list(value).filter_map { |bond|
      bond = bond.to_h.stringify_keys
      to, nature = bond["to"].to_s.squish, bond["bond"].to_s.squish
      { "to" => to, "bond" => nature } if to.present? || nature.present?
    })
  end

  def core_talent
    Grimwild.core_talent(path)
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
      list(value).map { _1.to_s.squish }.compact_blank
    end

    def starting_stats_add_up
      total = Grimwild::STATS.sum { |name| stat(name).to_i }
      unless total == STARTING_STAT_TOTAL
        errors.add(:base, "Stats should add up to #{STARTING_STAT_TOTAL} (1 in each, plus 4 points); they add up to #{total}")
      end
    end

    def seated_in_own_campaign
      if campaign && !identity&.memberships&.exists?(campaign: campaign)
        errors.add(:campaign, "must be one of your campaigns")
      end
    end
end
