import { Controller } from "@hotwired/stimulus"

// The table's rail. Its lines render once for everyone (they arrive over
// broadcasts), so the per-viewer part happens here: your own lines sit on the
// right.
//
// It also keeps your place. Reading the latest, new lines scroll into view;
// scrolled up into history, you stay put and a "3 new" pill offers the way
// back down. Your own lines and rolls always bring you to the latest.
//
// And it scrolls back forever: reaching the top loads the page before
// (Campaigns::FeedsController) above what's showing, until there's nothing
// earlier. Those lines aren't new, so they don't count toward the pill.
const NEAR_LATEST = 48 // px from the newest line that still counts as reading it

export default class extends Controller {
  static targets = ["scroller", "newPill", "newCount", "list", "older"]
  static values = { viewer: String, before: String, more: Boolean, olderUrl: String }

  connect() {
    this.element.querySelectorAll(".chat-line").forEach((line) => this.mark(line))
    this.seen = new Set([...this.element.querySelectorAll(".feed-item[id]")].map((item) => item.id))
    this.unread = 0
    this.scrolled()

    this.observer = new MutationObserver((changes) => {
      const arrived = []
      changes.forEach((change) => change.addedNodes.forEach((node) => {
        if (node.nodeType !== Node.ELEMENT_NODE || !node.matches(".feed-item")) return
        if (node.matches(".chat-line")) this.mark(node)
        // A replaced line (an updated roll) isn't new.
        if (node.id && !this.seen.has(node.id)) {
          this.seen.add(node.id)
          arrived.push(node)
        }
      }))
      if (arrived.length) this.arrived(arrived)
    })
    this.observer.observe(this.element, { childList: true, subtree: true })

    if (this.hasOlderTarget && this.hasScrollerTarget) {
      this.olderObserver = new IntersectionObserver((entries) => {
        if (entries.some((entry) => entry.isIntersecting)) this.loadOlder()
      }, { root: this.scrollerTarget, rootMargin: "300px 0px 0px 0px" })
      this.olderObserver.observe(this.olderTarget)
      this.renderOlder()
    }
  }

  disconnect() {
    this.observer?.disconnect()
    this.olderObserver?.disconnect()
  }

  // The page before the oldest line showing, put above it. The scroller is
  // column-reverse, so lines added up there don't move what you're reading.
  async loadOlder() {
    if (this.loading || !this.moreValue || !this.beforeValue || !this.hasListTarget) return
    this.loading = true
    this.renderOlder()

    try {
      const url = new URL(this.olderUrlValue, window.location.href)
      url.searchParams.set("before", this.beforeValue)
      const response = await fetch(url, { headers: { Accept: "text/html" }, credentials: "same-origin" })
      if (!response.ok) throw new Error(`HTTP ${response.status}`)

      const template = document.createElement("template")
      template.innerHTML = await response.text()
      const page = template.content.querySelector("[data-feed-page]")
      const lines = [...page.children].filter((line) => !line.id || !document.getElementById(line.id))
      lines.forEach((line) => line.id && this.seen.add(line.id))
      this.listTarget.prepend(...lines)

      this.beforeValue = page.dataset.before || ""
      this.moreValue = page.dataset.more === "true"
    } catch {
      this.moreValue = false
      document.dispatchEvent(new CustomEvent("toasts:show", { detail: { message: "Couldn't load earlier lines. Reload the page to try again." } }))
    } finally {
      this.loading = false
      this.renderOlder()
      this.scrolled()
    }

    // Still at the top (a short page, a tall window)? Keep going.
    if (this.moreValue && this.olderInView()) this.loadOlder()
  }

  olderInView() {
    const older = this.olderTarget.getBoundingClientRect()
    const scroller = this.scrollerTarget.getBoundingClientRect()
    return older.bottom >= scroller.top - 300 && older.top <= scroller.bottom
  }

  // Also after a morph, which renders the first page again.
  renderOlder() {
    if (!this.hasOlderTarget) return
    this.olderTarget.textContent = this.loading ? "Loading earlier lines…" : this.moreValue ? "" : (this.hasListTarget && this.listTarget.children.length ? "That's the start of the table." : "")
  }

  mark(line) {
    line.classList.toggle("chat-line--mine", line.dataset.identity === this.viewerValue)
  }

  // The scroller is column-reverse: scrollTop is 0 at the newest line and goes
  // negative going up, so "from the top" is what stays put while reading.
  scrolled() {
    if (!this.hasScrollerTarget) return
    const scroller = this.scrollerTarget
    const fromLatest = Math.abs(scroller.scrollTop)
    this.atLatest = fromLatest <= NEAR_LATEST
    this.fromTop = scroller.scrollHeight - scroller.clientHeight - fromLatest
    if (this.atLatest && this.unread) {
      this.unread = 0
      this.render()
    }
  }

  // Runs before the browser paints the new lines, so holding your place
  // doesn't flicker.
  arrived(lines) {
    if (!this.hasScrollerTarget) return
    const mine = lines.some((line) => line.dataset.identity === this.viewerValue)

    if (mine || this.atLatest) {
      this.toLatest()
    } else {
      const scroller = this.scrollerTarget
      scroller.scrollTop = -(scroller.scrollHeight - scroller.clientHeight - this.fromTop)
      // Lines the Story / Dice filter hides don't count.
      this.unread += lines.filter((line) => line.getClientRects().length > 0).length
      this.render()
    }
  }

  latest() {
    const smooth = !window.matchMedia("(prefers-reduced-motion: reduce)").matches
    this.scrollerTarget.scrollTo({ top: 0, behavior: smooth ? "smooth" : "auto" })
  }

  toLatest() {
    this.scrollerTarget.scrollTop = 0
    this.unread = 0
    this.render()
  }

  // Also after a morph, which re-renders the pill hidden.
  render() {
    this.renderOlder()
    if (!this.hasNewPillTarget) return
    this.newPillTarget.hidden = this.unread === 0
    this.newCountTarget.textContent = `${this.unread} new`
    this.newPillTarget.setAttribute("aria-label", `${this.unread} new in the table's chat and log: jump to the latest`)
  }
}
