import { Controller } from "@hotwired/stimulus"

// The chat box: Enter sends (Shift+Enter for a new line), and a sent message
// clears the box and keeps focus there. The line itself arrives over the chat
// stream, like everyone else's.
export default class extends Controller {
  static targets = ["body"]

  keydown(event) {
    if (event.target !== this.bodyTarget || event.key !== "Enter" || event.shiftKey || event.isComposing) return
    event.preventDefault()
    if (this.bodyTarget.value.trim() !== "") this.element.requestSubmit()
  }

  sent(event) {
    if (!event.detail.success) return
    this.bodyTarget.value = ""
    this.bodyTarget.focus()
  }
}
