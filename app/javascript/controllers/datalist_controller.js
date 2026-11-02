import { Controller } from "@hotwired/stimulus"

// A type-or-pick box whose text is already one of its list's options: the
// browser would suggest only that one, so focusing it empties the box (the
// value shows as its placeholder) to offer the whole list. Leaving without
// picking puts the value back, with no change event, and so does saving the
// form while the box is still empty and focused.
export default class extends Controller {
  connect() {
    this.restore = () => this.close()
    this.element.form?.addEventListener("submit", this.restore, true)
  }

  disconnect() {
    this.element.form?.removeEventListener("submit", this.restore, true)
    this.close()
  }

  open() {
    const value = this.element.value
    if (!value || !this.listed(value)) return

    this.kept = value
    this.placeholder = this.element.placeholder
    this.element.placeholder = value
    this.element.value = ""
  }

  close() {
    if (this.kept === undefined) return

    if (!this.element.value) this.element.value = this.kept
    this.element.placeholder = this.placeholder
    this.kept = undefined
  }

  listed(value) {
    return [...(this.element.list?.options || [])].some((option) => option.value === value)
  }
}
