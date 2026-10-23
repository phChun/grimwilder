import { Controller } from "@hotwired/stimulus"
import { rollDie } from "grimwild/dice"

// Rolls on a crucible's 6x6 tables. Each roll is 2d6 read two ways (pg. 6):
// first die = row, second = column, and switched. Results are chips; the
// first reading of each table starts chosen, tap another to choose it. "Keep"
// saves the chosen words as one line in a per-crucible list in localStorage.
// Tapping a chip also sends crucible:pick ({ word, table }), so a form around
// the roller can use the word (feature_fill_controller.js).
export default class extends Controller {
  static targets = ["table", "results", "keepButton", "keptSection", "keptList"]
  static values = { key: String }

  connect() {
    this.rolls = new Map() // table index -> { name, readings: [{row, col, word}], chosen }
    this.kept = this.loadKept()
    this.renderKept()
  }

  rollAll() {
    this.tableTargets.forEach((_, index) => this.roll(index))
    this.render()
  }

  rollOne(event) {
    this.roll(Number(event.params?.index ?? event.currentTarget.dataset.index))
    this.render()
  }

  roll(index) {
    const table = this.tableTargets[index]
    const a = rollDie(6)
    const b = rollDie(6)
    const pairs = a === b ? [[a, b]] : [[a, b], [b, a]]

    table.querySelectorAll("td.is-hit").forEach((cell) => cell.classList.remove("is-hit"))
    const readings = pairs.map(([row, col]) => {
      const cell = table.querySelector(`td[data-row="${row}"][data-col="${col}"]`)
      cell.classList.add("is-hit")
      return { row, col, word: cell.textContent.trim() }
    })

    this.rolls.set(index, { name: table.dataset.name, dice: [a, b], readings, chosen: 0 })
  }

  choose(event) {
    const { index, reading } = event.currentTarget.dataset
    const roll = this.rolls.get(Number(index))
    roll.chosen = Number(reading)
    this.render()
    this.dispatch("pick", { detail: { word: roll.readings[roll.chosen].word, table: roll.name } })
  }

  keep() {
    const line = this.chosenWords().join(" + ")
    if (!line) return
    this.kept.unshift(line)
    this.kept = this.kept.slice(0, 50)
    this.saveKept()
    this.renderKept()
  }

  async copyKept() {
    try {
      await navigator.clipboard.writeText(this.kept.join("\n"))
    } catch {
      // Clipboard blocked: the list is still on screen to copy by hand.
    }
  }

  clearKept() {
    this.kept = []
    this.saveKept()
    this.renderKept()
  }

  // --- rendering -------------------------------------------------------------

  render() {
    const sorted = [...this.rolls.entries()].sort(([a], [b]) => a - b)
    const blocks = sorted.map(([index, roll]) => {
      const block = document.createElement("div")
      block.className = "roll-result"

      const label = document.createElement("p")
      label.className = "roll-result__label"
      const dice = document.createElement("span")
      dice.className = "roll-result__roll"
      dice.textContent = `rolled ${roll.dice.join(" and ")}`
      label.append(`${roll.name} `, dice)
      block.append(label)

      const chips = document.createElement("div")
      chips.className = "roll-result__chips"
      roll.readings.forEach((reading, readingIndex) => {
        const chip = document.createElement("button")
        chip.type = "button"
        chip.className = "chip"
        chip.textContent = reading.word
        chip.title = `Row ${reading.row}, column ${reading.col}`
        chip.setAttribute("aria-pressed", String(readingIndex === roll.chosen))
        chip.dataset.index = index
        chip.dataset.reading = readingIndex
        chip.dataset.action = "crucible#choose"
        chips.append(chip)
      })
      block.append(chips)
      return block
    })

    const smash = document.createElement("p")
    smash.className = "roll-result__smash"
    smash.textContent = this.chosenWords().join(" + ")

    this.resultsTarget.replaceChildren(...blocks, smash)
    this.keepButtonTarget.disabled = this.rolls.size === 0
  }

  renderKept() {
    this.keptListTarget.replaceChildren(...this.kept.map((line) => {
      const item = document.createElement("li")
      item.textContent = line
      return item
    }))
    this.keptSectionTarget.hidden = this.kept.length === 0
  }

  chosenWords() {
    return [...this.rolls.entries()]
      .sort(([a], [b]) => a - b)
      .map(([, roll]) => roll.readings[roll.chosen].word)
  }

  // --- storage (per-browser convenience; failures are harmless) --------------

  get storageKey() {
    return `grimwilder:crucible:${this.keyValue}:kept`
  }

  loadKept() {
    try {
      return JSON.parse(localStorage.getItem(this.storageKey)) || []
    } catch {
      return []
    }
  }

  saveKept() {
    try {
      localStorage.setItem(this.storageKey, JSON.stringify(this.kept))
    } catch {
      // Private mode or storage full: keep the list for this page view only.
    }
  }
}
