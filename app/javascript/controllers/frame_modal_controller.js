import { Controller } from "@hotwired/stimulus"

// The modal that shows a page's <turbo-frame id="modal"> (shared/_frame_modal):
// a link with data-turbo-frame="modal" loads it, and this opens the dialog once
// it has, naming it after the page's heading. A form in it that saves closes
// it (it targets _top, so the page behind refreshes). Escape, the close button
// or a click outside close it too. Closing empties the frame, so the next open
// loads it fresh.
export default class extends Controller {
  static targets = ["frame"]

  open(event) {
    if (event.target !== this.frameTarget) return
    const heading = this.frameTarget.querySelector("h1, h2")
    if (heading) this.element.setAttribute("aria-label", heading.textContent.trim())
    if (!this.element.open) this.element.showModal()
  }

  submitted(event) {
    if (event.detail.success) this.close()
  }

  close() {
    if (this.element.open) this.element.close()
  }

  closed() {
    this.frameTarget.removeAttribute("src")
    this.frameTarget.replaceChildren()
  }

  // A click on the backdrop lands on the dialog itself, outside its box.
  backdrop(event) {
    if (event.target !== this.element) return
    const box = this.element.getBoundingClientRect()
    const inside = event.clientX >= box.left && event.clientX <= box.right && event.clientY >= box.top && event.clientY <= box.bottom
    if (!inside) this.close()
  }
}
