import { Controller } from "@hotwired/stimulus"

// The sheet's talent cards fold to their name and summary. When the page
// jumps to one (#talent-luck after rolling its pool, a notice's link to a
// card with picks to make), this opens it so what you came for shows.
export default class extends Controller {
  connect() {
    this.openTarget = this.openTarget.bind(this)
    window.addEventListener("hashchange", this.openTarget)
    this.openTarget()
  }

  disconnect() {
    window.removeEventListener("hashchange", this.openTarget)
  }

  openTarget() {
    const target = window.location.hash && document.getElementById(decodeURIComponent(window.location.hash.slice(1)))
    if (!target || !this.element.contains(target)) return

    const fold = target.querySelector(":scope > .talent-card__fold") || target.closest(".talent-card__fold")
    if (fold && !fold.open) {
      fold.open = true
      target.scrollIntoView({ block: "start" })
    }
  }
}
