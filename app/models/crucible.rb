# A crucible: one or more 6x6 tables of inspiration words from the book
# (config/crucibles.yml). Read-only reference data, so it isn't in the DB.
#
# Rolling (pg. 6): 2d6, one die picks the row and the other the column, "or
# switch them", so every roll reads two ways. Rolls happen in the browser
# (crucible_controller.js); this class just serves the tables.
class Crucible
  GROUPS = {
    "gm" => "For the GM",
    "places" => "Places and factions",
    "characters" => "Characters",
    "magic" => "Magic"
  }.freeze

  Table = Data.define(:name, :rows, :columns) do
    def cell(row, column)
      rows.fetch(row - 1).fetch(column - 1)
    end
  end

  attr_reader :key, :name, :group, :page, :blurb, :how, :tables

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

  def initialize(key:, name:, group:, page:, blurb:, how:, tables:)
    @key, @name, @group, @page, @blurb, @how = key, name, group, page, blurb, how
    @tables = tables.map { |table| Table.new(name: table["name"], rows: table["rows"], columns: table["columns"]) }
  end

  def to_param
    key
  end

  def group_name
    GROUPS.fetch(group)
  end
end
