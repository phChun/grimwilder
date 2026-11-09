import { Controller } from "@hotwired/stimulus"

// The character form's path (characters/_path_picker): the button opens a
// modal of path cards, whose radios are the form's own field. Picking one
// shows its summary on the form and closes the modal; Escape, its ✕ or a
// click outside close it without changing anything.
export default class extends Controller {
  static targets = ["dialog", "summary", "button"]

  open() {
    this.dialogTarget.showModal()
    this.dialogTarget.querySelector("input:checked")?.focus()
  }

  close() {
    if (this.dialogTarget.open) this.dialogTarget.close()
  }

  pick(event) {
    const path = event.target.value
    this.summaryTargets.forEach((summary) => { summary.hidden = summary.dataset.path !== path })
    this.buttonTarget.textContent = "Change path"
    this.close()
    this.buttonTarget.focus()
  }

  disconnect() {
    this.close()
  }

  // A click on the backdrop lands on the dialog itself, outside its box.
  backdrop(event) {
    if (event.target !== this.dialogTarget) return
    const box = this.dialogTarget.getBoundingClientRect()
    const inside = event.clientX >= box.left && event.clientX <= box.right && event.clientY >= box.top && event.clientY <= box.bottom
    if (!inside) this.close()
  }
}
