import { Controller } from "@hotwired/stimulus"

// Filters the crucibles list as you type: every word must appear in the
// crucible's name, blurb, group, table names or cells, so "lighthouse" finds
// the crucibles that can roll it. Groups with no matches are hidden.
export default class extends Controller {
  static targets = ["query", "item", "group", "count", "empty"]

  filter() {
    const words = this.queryTarget.value.toLowerCase().split(/\s+/).filter(Boolean)
    let shown = 0

    this.groupTargets.forEach((group) => {
      let matches = 0
      group.querySelectorAll("[data-crucible-filter-target=item]").forEach((item) => {
        const match = words.every((word) => item.dataset.search.includes(word))
        item.hidden = !match
        if (match) matches++
      })
      group.hidden = matches === 0
      shown += matches
    })

    this.countTarget.textContent = words.length ? `${shown} of ${this.itemTargets.length} crucibles match` : ""
    this.emptyTarget.hidden = shown > 0
  }
}
