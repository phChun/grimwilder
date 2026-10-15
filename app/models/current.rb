class Current < ActiveSupport::CurrentAttributes
  attribute :session, :identity

  def session=(value)
    super
    self.identity = value&.identity
  end
end
