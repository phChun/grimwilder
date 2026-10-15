# frozen_string_literal: true

ReActionView.configure do |config|
  # Hand HTML templates to ReActionView (validation, overlays, dev tools, reactive templates).
  config.intercept_erb = true

  # Reactive templates: herb:state, data-herb-* actions, and herb_state in controllers.
  config.slots = true

  config.debug_mode = Rails.env.development?
end
