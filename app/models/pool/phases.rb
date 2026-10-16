# Linked pools (pg. 19): two or more phases that unlock one at a time, written
# like the book: "8d Magic Shielding + 2d Wizard". Only the current phase rolls
# and drops; when it reaches 0d the next begins at full size, and the pool's
# event happens when the last one does.
module Pool::Phases
  extend ActiveSupport::Concern

  NOTATION = /\A(\d+)\s*d\s+(\S.*)\z/i

  included do
    before_validation :start_at_first_phase, on: :create, if: :linked?
    validate :phases_are_well_formed, if: :linked?
    after_save { @phases_text = nil }
  end

  def linked?
    phases.any?
  end

  def phase_name
    phases.dig(phase, "name")
  end

  def next_phase
    phases[phase + 1]
  end

  # What the GM typed, so a form shown again with an error keeps it as written.
  def phases_text
    @phases_text || phases.map { |entry| "#{entry["size"]}d #{entry["name"]}" }.join(" + ")
  end

  def phases_text=(text)
    @phases_text = text
    self.phases = text.to_s.split("+").map(&:squish).compact_blank.map do |part|
      match = NOTATION.match(part)
      { "name" => match ? match[2] : part, "size" => match&.[](1)&.to_i }
    end
  end

  private
    # A roll or push that leaves the current phase at 0d unlocks the next one.
    def next_phase_attributes(size)
      { phase: phase + 1, starting_size: next_phase["size"], size: next_phase["size"] } if size.zero? && next_phase
    end

    def first_phase_attributes
      linked? ? { phase: 0, starting_size: phases.first["size"], size: phases.first["size"] } : { size: starting_size }
    end

    def start_at_first_phase
      assign_attributes(first_phase_attributes) if phases.first["size"]
    end

    def phases_are_well_formed
      if phases.size < 2 || phases.any? { |entry| entry["name"].blank? || !entry["size"].to_i.in?(1..Pool::MAX_SIZE) }
        errors.add(:phases, "should be two or more, written like 4d Claws + 4d Tail (1–#{Pool::MAX_SIZE}d each)")
      end
    end
end
