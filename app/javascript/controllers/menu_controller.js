import { Controller } from "@hotwired/stimulus"

// A <details> whose panel floats under its button (a pool card's ⋯, "+ New
// pool"). When it opens, the panel is kept on screen: it opens upward if
// there's no room below, is nudged in from the side edges, and scrolls if it
// fits neither way. A click anywhere outside it, or Escape, closes it (a
// select's list, drawn on the page's body by selects_controller.js, counts as
// inside). A form in it that saves closes it; one that fails stays open to
// fix. (details-memory would otherwise reopen it after the refresh.)
const MARGIN = 8

export default class extends Controller {
  static targets = ["panel"]

  disconnect() {
    this.stopListening()
  }

  place() {
    if (!this.element.open) return this.stopListening()
    document.addEventListener("pointerdown", this.closeOutside, true)
    document.addEventListener("keydown", this.closeOnEscape)

    const panel = this.panelTarget
    panel.classList.remove("menu-panel--up")
    panel.style.translate = ""
    panel.style.maxHeight = ""

    const toggle = this.element.getBoundingClientRect()
    const below = window.innerHeight - toggle.bottom - MARGIN
    const above = toggle.top - MARGIN
    const height = panel.getBoundingClientRect().height
    if (height > below && above > below) {
      panel.classList.add("menu-panel--up")
      if (height > above) panel.style.maxHeight = `${above}px`
    } else if (height > below) {
      panel.style.maxHeight = `${below}px`
    }

    const box = panel.getBoundingClientRect()
    if (box.left < MARGIN) panel.style.translate = `${MARGIN - box.left}px 0`
    else if (box.right > window.innerWidth - MARGIN) panel.style.translate = `${window.innerWidth - MARGIN - box.right}px 0`
  }

  closeOnSuccess(event) {
    if (event.detail.success) this.element.open = false
  }

  closeOutside = (event) => {
    if (this.element.contains(event.target) || event.target.closest?.(".select-menu")) return
    this.element.open = false
  }

  closeOnEscape = (event) => {
    if (event.key !== "Escape" || event.defaultPrevented) return
    this.element.open = false
    this.element.querySelector("summary")?.focus()
  }

  stopListening() {
    document.removeEventListener("pointerdown", this.closeOutside, true)
    document.removeEventListener("keydown", this.closeOnEscape)
  }
}
