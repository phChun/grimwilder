import { Controller } from "@hotwired/stimulus"
import { rollDie } from "grimwild/dice"

// Rolls on a crucible's tables. On a 6x6 table each roll is 2d6 read two
// ways (pg. 6): first die = row, second = column, and switched. A narrower
// table (six rows of 1, 2 or 3 words) reads once: the first die picks the
// row, the second the column (a list needs only the first). A d8 table (eight
// rows of two) rolls one d8 for the row and offers both cells. The chosen words lead,
// smashed together; under them each table's roll is a row: its name, the dice, then
// the readings as chips; the first starts chosen, tap another to choose it. A lone
// reading is ember text, unless a form around the roller listens for crucible:pick,
// where tapping its chip fills a box. "Keep"
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
    const d8 = Number(table.dataset.rows) === 8
    const a = rollDie(d8 ? 8 : 6)
    const b = width === 1 || d8 ? null : rollDie(6)
    const pairs = d8 ? [[a, 1], [a, 2]]
      : width === 6 ? (a === b ? [[a, b]] : [[a, b], [b, a]])
      : [[a, b ? Math.ceil((b * width) / 6) : 1]]

    table.querySelectorAll("td.is-hit").forEach((cell) => cell.classList.remove("is-hit"))
    const readings = pairs.map(([row, col]) => {
      const cell = table.querySelector(`td[data-row="${row}"][data-col="${col}"]`)
      cell.classList.add("is-hit")
      return { row, col, word: cell.textContent.trim() }
    })

    this.rolls.set(index, { name: table.dataset.name, dice: [a, b].filter(Boolean), d8, readings, chosen: 0, fresh: true })
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
    const rows = sorted.map(([index, roll]) => {
      const row = document.createElement("li")
      row.className = "crucible-roll"

      const name = document.createElement("span")
      name.className = "crucible-roll__name"
      name.textContent = roll.name

      const dice = document.createElement("span")
      dice.className = "crucible-roll__dice"
      dice.append(...roll.dice.map((value) => {
        const die = document.createElement("span")
        die.className = `die ${roll.d8 ? "die--d8" : "die--d6"} die--28`
        if (!roll.fresh) die.style.animation = "none"
        die.setAttribute("aria-label", `${roll.d8 ? "d8" : "d6"} showing ${value}`)
        die.textContent = value
        return die
      }))

      const readings = document.createElement("span")
      readings.className = "crucible-roll__readings"
      if (roll.readings.length === 1 && !this.picks) {
        // Nothing to choose and nothing to fill: the word as text, not a button.
        const word = document.createElement("span")
        word.className = "crucible-roll__word"
        word.textContent = roll.readings[0].word
        readings.append(word)
      }
      else roll.readings.forEach((reading, readingIndex) => {
        const chip = document.createElement("button")
        chip.type = "button"
        chip.className = "chip"
        chip.textContent = reading.word
        chip.title = `Row ${reading.row}, column ${reading.col}`
        chip.setAttribute("aria-pressed", String(readingIndex === roll.chosen))
        chip.dataset.index = index
        chip.dataset.reading = readingIndex
        chip.dataset.action = "crucible#choose"
        readings.append(chip)
      })

      row.append(name, dice, readings)
      return row
    })
    sorted.forEach(([, roll]) => { roll.fresh = false })

    const smash = document.createElement("p")
    smash.className = "roll-result__smash"
    smash.textContent = this.chosenWords().join(" + ")

    const list = document.createElement("ul")
    list.className = "crucible__rows"
    list.append(...rows)

    this.resultsTarget.replaceChildren(smash, list)
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
