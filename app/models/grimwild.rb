# Reference lists from the book (config/grimwild.yml): paths, backgrounds,
# traits, desires, weapon styles, bonds and arcs.
module Grimwild
  STATS = %w[ brawn agility wits presence ].freeze
  PHYSICAL_STATS = %w[ brawn agility ].freeze
  MENTAL_STATS = %w[ wits presence ].freeze
  MAX_LEVEL = 7
  MAX_SPARK = 2

  class << self
    def data
      return load_data unless Rails.env.production?

      @data ||= load_data
    end

    %w[ stats paths backgrounds traits desires weapon_styles bond_intensities bond_natures arcs ].each do |key|
      define_method(key) { data.fetch(key) }
    end

    def core_talent(path)
      paths[path]
    end

    private
      def load_data
        YAML.load_file(Rails.root.join("config/grimwild.yml")).freeze
      end
  end
end
