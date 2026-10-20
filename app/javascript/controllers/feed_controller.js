import { Controller } from "@hotwired/stimulus"

// The table's rail. Its lines render once for everyone (they arrive over
// broadcasts), so the per-viewer parts happen here: your own lines sit on the
// right, and the best-moment star shows to whoever may pick it (the
// character's player or the GM for an in-character line; a player for
// narration, as their own character). The server checks all of it again.
export default class extends Controller {
  static targets = ["star"]
  static values = { viewer: String, gm: Boolean, session: Boolean }

  connect() {
    this.element.querySelectorAll(".chat-line").forEach((line) => this.mark(line))
    this.observer = new MutationObserver((changes) => {
      changes.forEach((change) => change.addedNodes.forEach((node) => {
        if (node.nodeType === Node.ELEMENT_NODE && node.matches(".chat-line")) this.mark(node)
      }))
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
        button.disabled = false
      }
    } catch {
      button.disabled = false
    }
  }
}
