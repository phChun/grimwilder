module IconsHelper
  # Inline stroke icons (24x24 grid, currentColor). Never emoji or glyphs.
  ICONS = {
    chevron: '<path d="M6 9l6 6 6-6"/>',
    link: '<path d="M10 14a4 4 0 0 0 5.7 0l3-3a4 4 0 0 0-5.7-5.7l-1 1"/><path d="M14 10a4 4 0 0 0-5.7 0l-3 3a4 4 0 0 0 5.7 5.7l1-1"/>',
    eye_off: '<path d="M3 3l18 18"/><path d="M10.6 5.1A10 10 0 0 1 12 5c5 0 9 4.5 10 7a12 12 0 0 1-2.6 3.6M6.6 6.6A12 12 0 0 0 2 12c1 2.5 5 7 10 7a10 10 0 0 0 4.4-1"/><path d="M9.9 9.9a3 3 0 0 0 4.2 4.2"/>',
    lock: '<rect x="5" y="11" width="14" height="10" rx="2"/><path d="M8 11V8a4 4 0 0 1 8 0v3"/>',
    die: '<rect x="4" y="4" width="16" height="16" rx="3"/><circle cx="9" cy="9" r="1" fill="currentColor"/><circle cx="15" cy="15" r="1" fill="currentColor"/><circle cx="15" cy="9" r="1" fill="currentColor"/><circle cx="9" cy="15" r="1" fill="currentColor"/>',
    send: '<path d="M5 12h14"/><path d="M13 6l6 6-6 6"/>',
    more: '<circle cx="6" cy="12" r="1" fill="currentColor"/><circle cx="12" cy="12" r="1" fill="currentColor"/><circle cx="18" cy="12" r="1" fill="currentColor"/>',
    close: '<path d="M6 6l12 12"/><path d="M18 6L6 18"/>',
    menu: '<path d="M4 7h16"/><path d="M4 12h16"/><path d="M4 17h16"/>',
    star: '<path d="M12 3.5l2.6 5.3 5.9.9-4.3 4.1 1 5.8-5.2-2.7-5.2 2.7 1-5.8-4.3-4.1 5.9-.9z"/>',
    check: '<path d="M5 12.5l4.5 4.5L19 7"/>',
    message: '<path d="M20 14a2 2 0 0 1-2 2H8l-4 4V6a2 2 0 0 1 2-2h12a2 2 0 0 1 2 2z"/>',
    list: '<path d="M9 6h11"/><path d="M9 12h11"/><path d="M9 18h11"/><path d="M4.5 6h.01"/><path d="M4.5 12h.01"/><path d="M4.5 18h.01"/>'
  }.freeze

  # Decorative by default; pass label: for an icon that stands alone.
  def icon(name, size: 16, label: nil)
    tag.svg(ICONS.fetch(name).html_safe, class: "icon icon--#{name.to_s.dasherize}", width: size, height: size, viewBox: "0 0 24 24",
      fill: "none", stroke: "currentColor", "stroke-width": 2, "stroke-linecap": "round", "stroke-linejoin": "round",
      role: (label ? "img" : nil), "aria-label": label, "aria-hidden": (label ? nil : "true"))
  end

  # The wordmark's dice: a d6 showing a perfect 6 in front of a thorn d8, its two
  # faces showing 8 and 7 (both cuts). The small icons (public/icon.svg) are the d6 alone.
  BRAND_MARK = '<path class="brand__d8" d="M440 48 L590 198 L290 198Z"/>' \
    '<path class="brand__d8 brand__d8--shade" d="M290 202 L590 202 L440 352Z"/>' \
    '<text class="brand__d8-number" x="458" y="148" text-anchor="middle" dominant-baseline="central">8</text>' \
    '<text class="brand__d8-number" x="458" y="252" text-anchor="middle" dominant-baseline="central">7</text>' \
    '<g transform="rotate(-8 190 200)"><rect class="brand__d6" x="50" y="60" width="280" height="280" rx="58"/>' \
    '<g class="brand__pips"><circle cx="128" cy="134" r="28"/><circle cx="252" cy="134" r="28"/><circle cx="128" cy="200" r="28"/>' \
    '<circle cx="252" cy="200" r="28"/><circle cx="128" cy="266" r="28"/><circle cx="252" cy="266" r="28"/></g></g>'

  def brand_mark
    tag.svg(BRAND_MARK.html_safe, class: "brand__mark", width: 46, height: 28, viewBox: "30 30 560 340", "aria-hidden": "true")
  end
end
