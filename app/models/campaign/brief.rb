# The party and the campaign as Markdown, for a GM to hand to an AI that helps
# them tell the story (Campaigns::BriefsController, "Copy for an AI" on the GM
# table): the campaign's pitch and rules, then each active character's story
# parts, who they are, what they want, their bonds and talents and how they're
# hurt right now, then any characters up for grabs. No stat numbers or dice, and nothing only the GM can see.
class Campaign::Brief
  def initialize(campaign)
    @campaign = campaign
  end

  def to_markdown
    [ campaign_section, party_section, up_for_grabs_section ].compact.join("\n\n").gsub(/\n{3,}/, "\n\n").strip + "\n"
  end

  private
    attr_reader :campaign

    def campaign_section
      lines = [ "# #{campaign.name}" ]
      lines << "*#{campaign.pitch}*" if campaign.pitch.present?
      lines << "A campaign of the tabletop RPG *Grimwild: Community Edition*, from Grimwilder. Use it as background for telling the story with this group."
      facts = {
        "Setting" => campaign.setting,
        "The party is" => campaign.party_is.to_sentence.presence,
        "The party is never" => campaign.party_never,
        "Group arc" => (title(campaign.group_arc) if campaign.group_arc.present?),
        "Optional rules in play" => campaign.rules_in_play.map(&:first).to_sentence.presence
      }.compact_blank
      lines << facts.map { "- **#{_1}:** #{_2}" }.join("\n") if facts.any?
      lines.join("\n\n")
    end

    def party_section
      characters = campaign.characters.played.active.includes(:identity).ordered.to_a
      return "## The party\n\nNo characters at the table yet." if characters.empty?

      ([ "## The party" ] + characters.map { character_section(_1, characters) }).join("\n\n")
    end

    # Characters the GM made for the table that no one has picked yet: ready
    # for the story to bring in.
    def up_for_grabs_section
      characters = campaign.characters.up_for_grabs.active.ordered.to_a
      return if characters.empty?

      ([ "## Up for grabs", "Characters made for this table that no player has picked yet." ] +
        characters.map { character_section(_1, characters, claimed: false) }).join("\n\n")
    end

    def character_section(character, party, claimed: true)
      core = character.core_talent_entry
      lines = [ "### #{character.name}" ]
      lines << "#{character.path}, level #{character.level} · #{claimed ? "played by #{character.identity.display_name}" : "not yet picked by a player"}"
      facts = {
        "Backgrounds" => character.backgrounds.map { |background| [ title(background["name"]), ("(wises: #{background["wises"].map { title(_1) }.join(", ")})" if background["wises"].any?) ].compact.join(" ") }.join("; "),
        "Traits" => with_not(character.traits, character.not_trait),
        "Desires" => with_not(character.desires, character.not_desire),
        "Features" => character.features.map { title(_1) }.join(", "),
        "Weapons" => [ character.weapons, *character.weapon_styles.map { title(_1) } ].compact_blank.join(", "),
        "Arcs" => character.arcs.map { title(_1) }.join("; "),
        "Bonds" => bonds(character, party),
        "Hurt right now" => helpers.harm_line(character),
        "Notes" => character.notes.to_s.squish.presence,
        "Talent notes" => character.talents.to_s.squish.presence
      }.compact_blank
      lines << facts.map { "- **#{_1}:** #{_2}" }.join("\n")
      lines << "**Talents**\n\n" + character.talent_entries.map { talent_line(character, _1, core) }.join("\n")
      lines.join("\n\n")
    end

    def talent_line(character, talent, core)
      picks = talent.choices.flat_map { character.picks_for(_1) }.map { title(_1) }
      "- **#{talent.name}**#{" (core)" if core && talent.key == core.key}: #{talent.summary}#{" Picks: #{picks.join(", ")}." if picks.any?}"
    end

    def bonds(character, party)
      others = party.reject { _1 == character }
      toward = others.filter_map { |other| (bond = character.bond_for(other)) && "#{other.short_name}: #{bond["bond"]}" if bond_text?(character.bond_for(other)) }
      beyond = character.bonds_beyond(others).filter_map { "#{_1["to"]}: #{_1["bond"]}" if _1["to"].present? && _1["bond"].present? }
      (toward + beyond).join("; ")
    end

    def bond_text?(bond)
      bond && bond["bond"].present?
    end

    def with_not(words, not_word)
      [ words.map { title(_1) }.join(", ").presence, ("not #{title(not_word)}" if not_word.present?) ].compact.join("; ")
    end

    def title(text)
      helpers.title_case(text.to_s)
    end

    def helpers
      ApplicationController.helpers
    end
end
