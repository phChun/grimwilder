import { Controller } from "@hotwired/stimulus"

// The table's rail. Its lines render once for everyone (they arrive over
// broadcasts), so the per-viewer parts happen here: your own lines sit on the
// right, and the best-moment star shows to whoever may pick it (the
// character's player or the GM for an in-character line; a player for
// narration, as their own character). The server checks all of it again.
//
// It also keeps your place. Reading the latest, new lines scroll into view;
// scrolled up into history, you stay put and a "3 new" pill offers the way
// back down. Your own lines and rolls always bring you to the latest.
const NEAR_LATEST = 48 // px from the newest line that still counts as reading it

export default class extends Controller {
  static targets = ["star", "scroller", "newPill", "newCount"]
  static values = { viewer: String, gm: Boolean, session: Boolean }

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
  }

  disconnect() {
    this.observer?.disconnect()
  }

  starTargetConnected(star) {
    const line = star.closest(".chat-line")
    star.hidden = !(line && this.sessionValue && this.canStar(line))
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
    if (!this.hasNewPillTarget) return
    this.newPillTarget.hidden = this.unread === 0
    this.newCountTarget.textContent = `${this.unread} new`
    this.newPillTarget.setAttribute("aria-label", `${this.unread} new in the table's chat and log: jump to the latest`)
  }

  canStar(line) {
    if (line.dataset.kind === "narration") return !this.gmValue
    return this.gmValue || line.dataset.owner === this.viewerValue
  }

  async star(event) {
    const button = event.currentTarget
    const token = document.querySelector("meta[name=csrf-token]")?.content
    button.disabled = true

    try {
      const response = await fetch(button.dataset.url, {
        method: "POST",
        headers: { "X-CSRF-Token": token, Accept: "text/vnd.turbo-stream.html" },
        credentials: "same-origin"
      })
      if (response.ok) {
        button.classList.add("feed-item__star--done")
        button.lastChild.textContent = " Starred for next session"
      } else {
        this.failed(button, "That star didn't save. Try again.")
      }
    } catch {
      this.failed(button, "Couldn't reach Grimwilder, so that star didn't save. Check your connection and try again.")
    }
  }

  failed(button, message) {
    button.disabled = false
    document.dispatchEvent(new CustomEvent("toasts:show", { detail: { message } }))
  }
}
