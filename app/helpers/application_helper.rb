module ApplicationHelper
  # Primary navigation for the play toolkit. `ready: false` items render as
  # "soon" so the site map is visible before every tool exists.
  TOOLKIT_NAV = [
    { label: "Roll", path: :roll_path, ready: true },
    { label: "Crucibles", path: :crucibles_path, ready: true },
    { label: "Characters", path: :characters_path, ready: true },
    { label: "Talents", path: :talents_path, ready: true }
  ].freeze

  def toolkit_nav
    TOOLKIT_NAV
  end
end
