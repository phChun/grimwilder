# A crucible: one or more tables of inspiration words from the book
# (config/crucibles.yml). Read-only reference data, so it isn't in the DB.
#
# Rolling (pg. 6): 2d6, one die picks the row and the other the column, "or
# switch them", so every roll on a 6x6 table reads two ways. Some crucibles
# are narrower (six rows of 1, 2 or 3 words: the seasons' lists, Build-a-
# vassal): the first die picks the row and the second the column, one
# reading. A d8 table is eight rows of two (roll d8, pick between them).
# Rolls happen in the browser (crucible_controller.js); this class
# just serves the tables. `credit` names whoever made one, where the book does.
class Crucible
  GROUPS = {
    "gm" => "For the GM",
    "places" => "Places and factions",
    "characters" => "Characters",
    "magic" => "Magic",
    "time" => "Time passing",
    "solo" => "Solo play",
    "monsters" => "Monsters"
  }.freeze
  WIDTHS = [ 1, 2, 3, 6 ].freeze

  Table = Data.define(:name, :rows, :columns) do
    def cell(row, column)
      rows.fetch(row - 1).fetch(column - 1)
    end

    def width
      rows.first.size
    end

    # A d8 table (the solo rules' consequences, pg. 194) is eight rows of two:
    # the d8 picks the row and you choose between its two cells.
    def d8?
      rows.size == 8
    end

    # Only a 6-row table with more than one column heads its columns.
    def headed?
      width > 1 && !d8?
    end

    # A column's own heading, or nil where it would only repeat the table's name
    # (Build-a-vassal's "Build, Build"): those show just their dice.
    def column_label(column)
      label = columns&.at(column)
      label unless label == name
    end

    # The second die's faces for a column of a 2- or 3-column table ("1–3", "5–6"),
    # as crucible_controller.js maps them (pg. 6); nil where the die is the column.
    def column_dice(column)
      return unless width.in?([ 2, 3 ]) && !d8?

      faces = 6 / width
      "#{column * faces + 1}–#{(column + 1) * faces}"
    end
  end

  attr_reader :key, :name, :group, :page, :blurb, :how, :tables, :credit

  class << self
    def all
      return load_all unless Rails.env.production?

      @all ||= load_all
    end

    def find(key)
      all.find { |crucible| crucible.key == key.to_s } || raise(ActiveRecord::RecordNotFound, "No crucible #{key.inspect}")
    end

    def grouped
      all.group_by(&:group).sort_by { |group, _| GROUPS.keys.index(group) || GROUPS.size }
    end

    private
      def load_all
        YAML.load_file(Rails.root.join("config/crucibles.yml")).map { |attributes| new(**attributes.symbolize_keys) }
      end
  end

  def initialize(key:, name:, group:, page:, blurb:, how:, tables:, credit: nil)
    @key, @name, @group, @page, @blurb, @how, @credit = key, name, group, page, blurb, how, credit
    @tables = tables.map { |table| Table.new(name: table["name"], rows: table["rows"], columns: table["columns"]) }
  end

  def to_param
    key
  end

  def group_name
    GROUPS.fetch(group)
  end

  # Everything the crucibles list's search looks through (crucible_filter_controller.js).
  def search_text
    [ name, blurb, group_name, *tables.flat_map { [ _1.name, *_1.columns, *_1.rows.flatten ] } ].uniq.join(" ").downcase
  end
end
