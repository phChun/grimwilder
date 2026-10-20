# A star on a chat line: someone's pick for a character's best moment this
# session (pg. 31). Moments are written at the start of the next session, so a
# nomination waits until then and fills in that character's moment prompt.
# Who may nominate follows the moment's own rule (Moment.writable_by?): the
# character's player or the GM. Each person keeps one pick per character per
# session; starring again replaces it.
class PlaySession::Nomination < ApplicationRecord
  belongs_to :play_session
  belongs_to :character
  belongs_to :identity
  belongs_to :message, optional: true

  validates :text, presence: true, length: { maximum: Message::MAX_LENGTH }

  # The character a star on this line is for: the speaker of an in-character
  # line, or, for narration, the nominator's own active character here.
  def self.character_for(message, by:)
    if message.in_character? then message.character
    elsif message.narration? then Membership.find_by(campaign: message.campaign, identity: by)&.seated_character
    end
  end

  def self.nominate!(message, by:)
    session = message.campaign.current_session
    character = character_for(message, by: by)

    raise ArgumentError, "Best moments come from in-character lines and narration." unless message.nominatable?
    raise ArgumentError, "Star a moment while a session is going." unless session
    raise ArgumentError, "Only a character's player or the GM can pick their best moment." unless character && PlaySession::Moment.writable_by?(by, character, message.campaign)

    find_or_initialize_by(play_session: session, character: character, identity: by).tap do |nomination|
      nomination.update!(message: message, text: message.body)
    end
  end

  # What to prefill a character's moment prompt with: the latest star from the
  # session before, preferring the prompting person's own pick.
  def self.prefill_for(session, character, identity)
    previous = session.previous or return
    picks = where(play_session: previous, character: character).order(updated_at: :desc)
    (picks.find_by(identity: identity) || picks.first)&.text
  end
end
