import { Controller } from "@hotwired/stimulus"

// Text cut off with an ellipsis (an admin table's long notes and emails) shows
// in full in a tooltip on hover or focus, only when it's actually cut off.
// The tip is fixed to the window, so a scrolling table can't clip it.
export default class extends Controller {
  show() {
    if (this.tip || this.element.scrollWidth <= this.element.clientWidth) return

    this.tip = document.createElement("div")
    this.tip.className = "floating-tip"
    this.tip.setAttribute("role", "tooltip")
    this.tip.textContent = this.element.textContent.trim()
    document.body.append(this.tip)

    const box = this.element.getBoundingClientRect()
    const tip = this.tip.getBoundingClientRect()
    const above = box.top - tip.height - 6
    this.tip.style.top = `${above > 8 ? above : box.bottom + 6}px`
    this.tip.style.left = `${Math.min(Math.max(8, box.left), window.innerWidth - tip.width - 8)}px`
  }

  hide() {
    this.tip?.remove()
    this.tip = null
  }

  disconnect() {
    this.hide()
  }
}
