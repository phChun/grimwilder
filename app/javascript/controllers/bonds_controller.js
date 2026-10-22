import { Controller } from "@hotwired/stimulus"

// The character form's bonds to NPCs and others: "Add an NPC" copies the
// blank row in the template, numbered after the rows already there, and
// focuses its name.
export default class extends Controller {
  static targets = ["list", "template"]
  static values = { next: Number }

  add() {
    const html = this.templateTarget.innerHTML.replaceAll("__INDEX__", this.nextValue++)
    this.listTarget.insertAdjacentHTML("beforeend", html)
    this.listTarget.lastElementChild.querySelector("input")?.focus()
  }
}
