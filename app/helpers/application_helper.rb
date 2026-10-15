module ApplicationHelper
  # Primary navigation for the play toolkit. `ready: false` items render as
  # "soon" so the site map is visible before every tool exists.
  TOOLKIT_NAV = [
    { label: "Roll", path: :roll_path, ready: true },
    { label: "Pools", path: :pools_path, ready: false },
    { label: "Crucibles", path: :crucibles_path, ready: false },
    { label: "Characters", path: :characters_path, ready: false }
  ].freeze

  def toolkit_nav
    TOOLKIT_NAV
  end
end
