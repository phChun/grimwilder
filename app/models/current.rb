class Current < ActiveSupport::CurrentAttributes
  attribute :session, :identity, :campaign, :membership

  def session=(value)
    super
    self.identity = value&.identity
  end
end
