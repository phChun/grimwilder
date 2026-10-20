# The table's rail: chat messages and log entries in one time-ordered stream.
# They stay separate models (Message, Roll); this only merges what a member may
# see, for the view, and names the streams that keep it live.
class TableFeed
  LOG_SIZE = 20

  attr_reader :campaign, :membership

  def initialize(campaign, membership, messages: Message::CHAT_SIZE, rolls: LOG_SIZE)
    @campaign, @membership = campaign, membership
    @message_limit, @roll_limit = messages, rolls
  end

  # Oldest first, the way a chat reads.
  def entries
    @entries ||= (messages + rolls).sort_by { [ _1.created_at, _1.is_a?(Roll) ? 0 : 1, _1.id ] }
  end

  def streams
    Roll.streams_for(campaign, membership) + Message.streams_for(campaign, membership)
  end

  private
    def messages
      Message.chat_for(campaign, membership, limit: @message_limit)
    end

    def rolls
      campaign.rolls.table_log(membership, limit: @roll_limit).to_a
    end
end
