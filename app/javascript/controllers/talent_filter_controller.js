import { Controller } from "@hotwired/stimulus"

// Filters the talent catalog. The dropdown shows one path's talents (or
// Background's, or all of them), and the search narrows that as you type:
// every word must appear in the talent's name, path or text. Groups with no
// matches are hidden. The dropdown's choice goes in the URL (?path=), so a
// reload or a shared link opens on the same path.
export default class extends Controller {
  static targets = ["query", "path", "item", "group", "count"]

  filter() {
    const words = this.queryTarget.value.toLowerCase().split(/\s+/).filter(Boolean)
    const path = this.hasPathTarget ? this.pathTarget.value : ""
    let shown = 0, total = 0

    this.groupTargets.forEach((group) => {
      const chosen = !path || group.dataset.key === path
      let matches = 0
      group.querySelectorAll("[data-talent-filter-target=item]").forEach((item) => {
        const match = chosen && words.every((word) => item.dataset.search.includes(word))
        item.hidden = !match
        if (chosen) total++
        if (match) matches++
      })
      group.hidden = matches === 0
      shown += matches
    })

    this.countTarget.textContent = words.length ? `${shown} of ${total} talents match` : ""
    this.remember(path)
  }

  remember(path) {
    const url = new URL(window.location.href)
    path ? url.searchParams.set("path", path) : url.searchParams.delete("path")
    window.history.replaceState(window.history.state, "", url)
  }
}
