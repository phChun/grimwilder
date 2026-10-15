import { Controller } from "@hotwired/stimulus"

// Filters the talent catalog as you type: every word must appear in the
// talent's name, path or text. Paths with no matches are hidden.
export default class extends Controller {
  static targets = ["query", "item", "group", "count"]

  filter() {
    const words = this.queryTarget.value.toLowerCase().split(/\s+/).filter(Boolean)
    let shown = 0

    this.itemTargets.forEach((item) => {
      const match = words.every((word) => item.dataset.search.includes(word))
      item.hidden = !match
      if (match) shown++
    })

    this.groupTargets.forEach((group) => {
      group.hidden = !group.querySelector("[data-talent-filter-target=item]:not([hidden])")
    })

    this.countTarget.textContent = words.length ? `${shown} of ${this.itemTargets.length} talents match` : ""
  }
}
