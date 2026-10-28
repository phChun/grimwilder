# What the GM decides about characters at the table, in settings:
#
# - `players_make_characters` (on by default): off, only the GM makes them
#   (up for grabs, for players to pick), and players can't seat their own.
# - `starting_level` (nil: players choose): the level new characters start at.
# - `players_set_level` (on by default): off, a level only changes with XP or
#   a milestone, not from the sheet's form.
# - `allowed_paths` (empty: every path): the paths characters here can take.
#   Settings shows every path ticked when they're all open; ticking them all
#   stores empty (so paths added later are open too), and none is refused.
module Campaign::CharacterSettings
  extend ActiveSupport::Concern

  included do
    validates :starting_level, numericality: { only_integer: true, in: 0..Grimwild::MAX_LEVEL }, allow_nil: true
    validate :starting_level_zero_needs_its_rule
    validate :some_path_open
  end

  def allowed_paths=(value)
    paths = Array(value).map(&:to_s) & Grimwild.paths.keys
    @no_path_open = paths.empty?
    super(paths.sort == Grimwild.paths.keys.sort ? [] : paths)
  end

  def path_allowed?(path)
    allowed_paths.empty? || allowed_paths.include?(path.to_s)
  end

  def paths_open
    allowed_paths.presence || Grimwild.paths.keys
  end

  # Whether this person may make or seat a character of their own here.
  def makes_characters?(identity)
    players_make_characters? || identity&.membership_in(self)&.gm? || false
  end

  private
    def some_path_open
      errors.add(:base, "Keep at least one path open.") if @no_path_open
    end

    def starting_level_zero_needs_its_rule
      errors.add(:starting_level, "can be 0 only with the Level 0 rule on") if starting_level&.zero? && !optional_rule?(:level_zero)
    end
end
