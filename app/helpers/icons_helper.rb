module IconsHelper
  # Inline stroke icons (24x24 grid, currentColor). Never emoji or glyphs.
  ICONS = {
    chevron: '<path d="M6 9l6 6 6-6"/>',
    link: '<path d="M10 14a4 4 0 0 0 5.7 0l3-3a4 4 0 0 0-5.7-5.7l-1 1"/><path d="M14 10a4 4 0 0 0-5.7 0l-3 3a4 4 0 0 0 5.7 5.7l1-1"/>',
    eye_off: '<path d="M3 3l18 18"/><path d="M10.6 5.1A10 10 0 0 1 12 5c5 0 9 4.5 10 7a12 12 0 0 1-2.6 3.6M6.6 6.6A12 12 0 0 0 2 12c1 2.5 5 7 10 7a10 10 0 0 0 4.4-1"/><path d="M9.9 9.9a3 3 0 0 0 4.2 4.2"/>',
    lock: '<rect x="5" y="11" width="14" height="10" rx="2"/><path d="M8 11V8a4 4 0 0 1 8 0v3"/>',
    star: '<path d="M12 3l2.7 5.6 6.1.9-4.4 4.3 1 6.1L12 17l-5.4 2.9 1-6.1-4.4-4.3 6.1-.9z"/>',
    die: '<rect x="4" y="4" width="16" height="16" rx="3"/><circle cx="9" cy="9" r="1" fill="currentColor"/><circle cx="15" cy="15" r="1" fill="currentColor"/><circle cx="15" cy="9" r="1" fill="currentColor"/><circle cx="9" cy="15" r="1" fill="currentColor"/>',
    send: '<path d="M5 12h14"/><path d="M13 6l6 6-6 6"/>',
    more: '<circle cx="6" cy="12" r="1" fill="currentColor"/><circle cx="12" cy="12" r="1" fill="currentColor"/><circle cx="18" cy="12" r="1" fill="currentColor"/>',
    close: '<path d="M6 6l12 12"/><path d="M18 6L6 18"/>'
  }.freeze

  # Decorative by default; pass label: for an icon that stands alone.
  def icon(name, size: 16, label: nil)
    tag.svg(ICONS.fetch(name).html_safe, class: "icon icon--#{name.to_s.dasherize}", width: size, height: size, viewBox: "0 0 24 24",
      fill: "none", stroke: "currentColor", "stroke-width": 2, "stroke-linecap": "round", "stroke-linejoin": "round",
      role: (label ? "img" : nil), "aria-label": label, "aria-hidden": (label ? nil : "true"))
  end

  # The wordmark's hexagon d6.
  def brand_mark
    tag.svg('<path d="M13 2l9.5 5.5v11L13 24l-9.5-5.5v-11z"/><path d="M13 2v22M3.5 7.5l19 11M22.5 7.5l-19 11"/>'.html_safe,
      class: "brand__mark", width: 26, height: 26, viewBox: "0 0 26 26", fill: "none", stroke: "currentColor", "stroke-width": 1.6, "aria-hidden": "true")
  end
end
