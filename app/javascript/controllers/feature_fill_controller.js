import { Controller } from "@hotwired/stimulus"

// The character form's distinctive features, filled from the features
// crucible rolled right beside them: a tapped word (crucible:pick) goes into
// the next empty box with what it describes ("frayed clothes"), ready to edit.
export default class extends Controller {
  static targets = ["input", "status"]
  static values = { nouns: Object }

  fill({ detail: { word, table } }) {
    const empty = this.inputTargets.find((input) => !input.value.trim())
    if (!empty) {
      this.statusTarget.textContent = "All three are filled. Clear one to use another word."
      return
    }

    const noun = this.nounsValue[table]
    empty.value = noun ? `${word} ${noun}` : word
    empty.dispatchEvent(new Event("input", { bubbles: true }))
    this.statusTarget.textContent = `Added “${empty.value}”. Change it however you like.`
  }
}
