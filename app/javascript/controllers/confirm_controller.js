import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

// The confirmation dialog (shared/_confirm) in place of the browser's
// confirm(): Turbo asks it for every data-turbo-confirm, on forms and on
// button_to buttons. It shows the message, and a confirm button saying what was
// clicked ("Delete", "Rest", "Give Tibbs back"), red when that deletes or
// removes. It answers false for Cancel, Escape or a click outside.
export default class extends Controller {
  static targets = ["message", "cancelButton", "acceptButton"]

  connect() {
    this.method = (message, form, submitter) => this.ask(message, form, submitter)
    Turbo.config.forms.confirm = this.method
  }

  disconnect() {
    if (Turbo.config.forms.confirm === this.method) Turbo.config.forms.confirm = undefined
    this.answer(false)
  }

  ask(message, form, submitter) {
    this.answer(false)
    const button = submitter || form?.querySelector("button[type=submit], input[type=submit]")
    const label = (button?.textContent || button?.value || "").trim() || "Continue"
    const danger = Boolean(button?.matches(".button--danger, .button--danger-text")) || /^(delete|remove)\b/i.test(label)

    this.messageTarget.textContent = message
    this.acceptButtonTarget.textContent = label
    this.acceptButtonTarget.classList.toggle("button--primary", !danger)
    this.acceptButtonTarget.classList.toggle("button--danger", danger)

    this.element.showModal()
    this.cancelButtonTarget.focus()
    return new Promise((resolve) => { this.resolve = resolve })
  }

  accept() {
    this.answer(true)
  }

  cancel(event) {
    event?.preventDefault()
    this.answer(false)
  }

  // A click on the backdrop lands on the dialog itself, outside its box (one
  // on the dialog's own padding does too, but inside).
  backdrop(event) {
    if (event.target !== this.element) return
    const box = this.element.getBoundingClientRect()
    const inside = event.clientX >= box.left && event.clientX <= box.right && event.clientY >= box.top && event.clientY <= box.bottom
    if (!inside) this.answer(false)
  }

  // Closed some other way (a form method="dialog", the browser): that's a no.
  closed() {
    this.answer(false)
  }

  answer(yes) {
    const resolve = this.resolve
    this.resolve = null
    if (this.element.open) this.element.close()
    resolve?.(yes)
  }
}
