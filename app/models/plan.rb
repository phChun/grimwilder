# A plan an account is on (config/plans.yml): how many active campaigns it
# may run as GM and play in. Read-only reference data, so it isn't in the DB;
# the account keeps its key in identities.plan.
Plan = Data.define(:key, :name, :running, :playing) do
  class << self
    def all
      return load_all unless Rails.env.production?

      @all ||= load_all
    end

    def keys
      all.map(&:key)
    end

    def find(key)
      all.find { |plan| plan.key == key.to_s } || raise(ActiveRecord::RecordNotFound, "No plan #{key.inspect}")
    end

    private
      def load_all
        YAML.load_file(Rails.root.join("config/plans.yml")).map { |attributes| new(**attributes.symbolize_keys) }
      end
  end

  # The limit for a role at the table ("gm" runs, "player" plays); nil is none.
  def limit_for(role)
    role.to_s == "gm" ? running : playing
  end

  def to_param
    key
  end
end
