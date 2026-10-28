# The GM's settings at the character's table (Campaign::CharacterSettings and
# the optional rules for character options), checked when they'd change
# something: a character made or seated there, a path or an option taken up.
# A character with no table answers to no GM, so everything's open to them.
module Character::TableSettings
  extend ActiveSupport::Concern

  included do
    before_validation :start_at_table_level, on: :create
    validate :seated_by_someone_allowed, if: -> { campaign && will_save_change_to_campaign_id? }
    validate :path_open_here, if: -> { campaign && (new_record? || will_save_change_to_path? || will_save_change_to_campaign_id?) }
    validate :options_allowed_here
  end

  # Stat progression, legacy cores, level 0: the GM's say-so at this table.
  def rule_allows?(rule)
    campaign.nil? || campaign.optional_rule?(rule)
  end

  def sets_own_level?
    campaign.nil? || campaign.players_set_level?
  end

  private
    # A table with a starting level puts new characters there.
    def start_at_table_level
      return unless (start = campaign&.starting_level)

      self.level = start
      self.level_zero = start.zero?
    end

    def seated_by_someone_allowed
      errors.add(:base, "The GM makes the characters at #{campaign.name}.") unless campaign.makes_characters?(identity)
    end

    def path_open_here
      errors.add(:path, "isn't open at #{campaign.name}") unless campaign.path_allowed?(path)
    end

    def options_allowed_here
      errors.add(:legacy_core, "isn't on at #{campaign.name}") if legacy_core? && will_save_change_to_legacy_core? && !rule_allows?(:legacy_cores)
      errors.add(:level_zero, "isn't on at #{campaign.name}") if new_record? && level_zero? && !campaign&.starting_level&.zero? && !rule_allows?(:level_zero)
    end
end
