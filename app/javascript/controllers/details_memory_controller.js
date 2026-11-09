import { Controller } from "@hotwired/stimulus"

// Remembers which <details> are open on the GM table, and puts them back after
// a Turbo morph (a pool refresh re-renders the page with the server's
// defaults, which would close whatever someone had opened).
//
// Sections (data-details-memory-target="section", data-section="pools") are
// remembered per browser in localStorage, keyed by campaign and section. With
// nothing saved, phones open only the ones marked data-phone-open; desktops
// keep the server's defaults. Other <details> on the page (a pool's ⋯) are
// remembered only until the page is left.
export default class extends Controller {
  static targets = ["section"]
  static values = { campaign: String }

  connect() {
    this.open = new Map() // details id -> open, for everything toggled this visit
    this.expected = new Map() // details id -> open, for changes made here (not by a person)
    this.phone = window.matchMedia("(max-width: 47.99rem)").matches

    this.sectionTargets.forEach((details) => {
      const saved = this.load(details.dataset.section)
      if (saved !== null) this.set(details, saved)
      else if (this.phone) this.set(details, details.dataset.phoneOpen === "true")
    })
    this.openLinkedSection()
  }

  // A link to a folded section (the sheet's #table-rolls) opens it.
  openLinkedSection() {
    const details = location.hash && document.getElementById(location.hash.slice(1))
    if (details instanceof HTMLDetailsElement && this.sectionTargets.includes(details)) this.set(details, true)
  }

  // toggle doesn't bubble, so this listens in the capture phase (see the view).
  toggled(event) {
    const details = event.target
    if (!(details instanceof HTMLDetailsElement) || !details.id) return

    if (this.expected.get(details.id) === details.open) {
      this.expected.delete(details.id)
      return
    }

    this.open.set(details.id, details.open)
    if (details.dataset.section) this.save(details.dataset.section, details.open)
  }

  // After a morph, put back what people had opened or closed.
  restore() {
    this.open.forEach((open, id) => {
      const details = document.getElementById(id)
      if (details) this.set(details, open)
    })
    this.sectionTargets.forEach((details) => {
      if (this.open.has(details.id)) return
      const saved = this.load(details.dataset.section)
      if (saved !== null) this.set(details, saved)
      else if (this.phone) this.set(details, details.dataset.phoneOpen === "true")
    })
  }

  // Expand all / Collapse all (data-details-memory-open-param): every fold
  // (details.sheet-fold) at once; sections are remembered as if opened or
  // closed by hand.
  foldAll(event) {
    this.element.querySelectorAll("details.sheet-fold").forEach((details) => { details.open = event.params.open })
  }

  // Section shortcuts and the settings button open the section they point at.
  jump(event) {
    const id = new URL(event.currentTarget.href).hash.slice(1)
    const details = document.getElementById(id)
    if (details instanceof HTMLDetailsElement && !details.open) details.open = true
  }

  set(details, open) {
    if (details.open === open) return
    this.expected.set(details.id, open)
    details.open = open
  }

  key(section) {
    return `grimwilder:campaign:${this.campaignValue}:section:${section}`
  }

  load(section) {
    try {
      const value = localStorage.getItem(this.key(section))
      return value === null ? null : value === "open"
    } catch {
      return null
    }
  }

  save(section, open) {
    try {
      localStorage.setItem(this.key(section), open ? "open" : "closed")
    } catch {
      // Private mode or storage blocked: sections fall back to their defaults.
    }
  }
}
