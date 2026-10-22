module ApplicationCable
  # Knows who's connected, from the same signed session cookie as requests.
  # Anyone may connect (Turbo Streams' signed stream names guard those);
  # channels that need a person, like PresenceChannel, reject when there's none.
  class Connection < ActionCable::Connection::Base
    identified_by :current_identity

    def connect
      self.current_identity = Session.find_signed(cookies.signed[:session_token])&.identity
    end
  end
end
