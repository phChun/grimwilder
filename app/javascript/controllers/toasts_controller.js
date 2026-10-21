import { Controller } from "@hotwired/stimulus"

// The failure toasts at the top of the screen (shared/_toasts). The server
// renders the ones it knows about; this adds the ones only the browser knows:
// a form that couldn't reach the server, or a `toasts:show` event
// ({ detail: { message } }) from a controller whose own fetch failed.
export default class extends Controller {
  static targets = ["template"]

  // Turbo couldn't reach the server. GETs (links, prefetches) aren't saves.
  unreachable(event) {
    const method = String(event.detail.request?.method || "get").toUpperCase()
    if (method === "GET") return
    this.show("Couldn't reach Grimwilder, so that didn't save. Check your connection and try again.")
  }

  announce(event) {
    if (event.detail?.message) this.show(event.detail.message)
  }

  show(message) {
    const toast = this.templateTarget.content.firstElementChild.cloneNode(true)
    const key = Math.random().toString(36).slice(2)
    toast.id = `toast-${key}`
    toast.dataset.toastKeyValue = key
    toast.querySelector(".toast__message").textContent = message
    this.element.append(toast)
  }

  // Don't let Turbo's page cache bring an old failure back.
  clear() {
    this.element.querySelectorAll(".toast").forEach((toast) => toast.remove())
  }
}
