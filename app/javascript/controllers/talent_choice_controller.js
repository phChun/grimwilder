import { Controller } from "@hotwired/stimulus"

// One choice on the talent choices form (characters/talent_choices/edit):
// keeps its "2 of 3" count current and, for a list of checkboxes, disables
// the unticked ones once the slots are full. The server checks again.
export default class extends Controller {
  static targets = ["count", "input"]
  static values = { slots: Number }

  connect() {
    this.update()
  }

  update() {
    const picked = this.inputTargets.filter((input) => input.type === "checkbox" ? input.checked : input.value.trim() !== "").length
    const full = picked >= this.slotsValue

    this.countTarget.textContent = `${picked} of ${this.slotsValue}`
    this.inputTargets.forEach((input) => {
      if (input.type === "checkbox") input.disabled = full && !input.checked
    })
  }
}
