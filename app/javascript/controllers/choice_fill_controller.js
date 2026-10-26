import { Controller } from "@hotwired/stimulus"

// The talent choices form (characters/talent_choices/edit), filled from the
// crucible rolled at its foot: a tapped word (crucible:pick) goes into the
// next box of the choice it's for. A choice says which crucible and table it
// takes (Pact's natures from Nature, desires from Desires) and how many words
// make one pick: a spell theorem is two ("wild fire"), so the second word
// joins the first.
export default class extends Controller {
  static targets = ["choice", "status"]

  fill({ detail: { word, table } }) {
    const choice = this.choiceTargets.find((element) => element.dataset.crucible && (!element.dataset.table || element.dataset.table === table))
    if (!choice) return

    const words = Number(choice.dataset.words) || 1
    const inputs = [...choice.querySelectorAll("input[type=text]")]
    const input = inputs.find((box) => box.value.trim().split(/\s+/).filter(Boolean).length < words)
    if (!input) {
      this.say(`Every ${choice.querySelector(".field__label").textContent.toLowerCase()} box is full. Clear one to use “${word}”.`)
      return
    }

    input.value = input.value.trim() ? `${input.value.trim()} ${word}` : word
    input.dispatchEvent(new Event("input", { bubbles: true }))
    this.say(`Added “${word}”. Change it however you like.`)
  }

  say(message) {
    if (this.hasStatusTarget) this.statusTarget.textContent = message
  }
}
