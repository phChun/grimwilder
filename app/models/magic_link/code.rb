# Codes use Crockford-ish base32 so they're easy to read aloud and type;
# letters people confuse with digits are mapped before lookup.
module MagicLink::Code
  SUBSTITUTIONS = { "O" => "0", "I" => "1", "L" => "1" }.freeze

  class << self
    def generate(length)
      SecureRandom.base32(length)
    end

    def sanitize(code)
      return if code.blank?

      normalized = SUBSTITUTIONS.reduce(code.to_s.upcase) { |result, (from, to)| result.gsub(from, to) }
      normalized.gsub(/[^#{SecureRandom::BASE32_ALPHABET.join}]/, "")
    end
  end
end
