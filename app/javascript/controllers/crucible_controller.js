import { Controller } from "@hotwired/stimulus"
import { rollDie } from "grimwild/dice"

// Rolls on a crucible's tables. On a 6x6 table each roll is 2d6 read two
// ways (pg. 6): first die = row, second = column, and switched. A narrower
// table (six rows of 1, 2 or 3 words) reads once: the first die picks the
// row, the second the column (a list needs only the first). Each table's roll is a
// card: its name, the dice, then the readings as chips; the first starts chosen,
// tap another to choose it. A lone reading is plain text, unless a form around
// the roller listens for crucible:pick, where tapping it fills a box. "Keep"
// saves the chosen words as one line in a per-crucible list in localStorage.
// Tapping a chip also sends crucible:pick ({ word, table }), so a form around
// the roller can use the word (feature_fill_controller.js), and Keep sends
// crucible:kept on window for the Kept crucibles card.
export default class extends Controller {
  static targets = ["table", "results", "keepButton", "keptSection", "keptList"]
  static values = { key: String }

  connect() {
    this.rolls = new Map() // table index -> { name, readings: [{row, col, word}], chosen }
    this.kept = this.loadKept()
    this.picks = Boolean(this.element.closest("[data-action*='crucible:pick']"))
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
    const width = Number(table.dataset.width) || 6
    const a = rollDie(6)
    const b = width === 1 ? null : rollDie(6)
    const pairs = width === 6 ? (a === b ? [[a, b]] : [[a, b], [b, a]]) : [[a, b ? Math.ceil((b * width) / 6) : 1]]

    table.querySelectorAll("td.is-hit").forEach((cell) => cell.classList.remove("is-hit"))
    const readings = pairs.map(([row, col]) => {
      const cell = table.querySelector(`td[data-row="${row}"][data-col="${col}"]`)
      cell.classList.add("is-hit")
      return { row, col, word: cell.textContent.trim() }
    })

    this.rolls.set(index, { name: table.dataset.name, dice: [a, b].filter(Boolean), readings, chosen: 0 })
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
    this.dispatch("kept", { target: window })
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
      label.textContent = roll.name
      const dice = document.createElement("p")
      dice.className = "roll-result__roll"
      dice.textContent = `Rolled ${roll.dice.join(" and ")}`
      block.append(label, dice)

      if (roll.readings.length === 1 && !this.picks) {
        const text = document.createElement("p")
        text.className = "roll-result__text"
        text.textContent = roll.readings[0].word
        block.append(text)
        return block
      }

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

  // The full page lists kept lines here; the compact roller leaves them to the Kept crucibles card.
  renderKept() {
    if (!this.hasKeptListTarget) return

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
