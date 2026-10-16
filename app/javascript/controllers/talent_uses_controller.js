import { Controller } from "@hotwired/stimulus"

// The sheet's talent-use boxes: when "Post to the table log" is ticked, each
// box's form also sends note=1. The tick is remembered per browser.
export default class extends Controller {
  static targets = ["note"]

  connect() {
    if (!this.hasNoteTarget) return
    try {
      this.noteTarget.checked = localStorage.getItem("grimwilder:talent-uses:note") === "1"
    } catch {
      // Storage blocked: the box just starts unticked.
    }
    this.element.addEventListener("submit", this.addNote)
  }

  disconnect() {
    this.element.removeEventListener("submit", this.addNote)
  }

  remember() {
    try {
      localStorage.setItem("grimwilder:talent-uses:note", this.noteTarget.checked ? "1" : "0")
    } catch {
      // Storage blocked: fine for this page view.
    }
  }

  addNote = (event) => {
    if (!this.noteTarget.checked || !event.target.matches(".use-box__form")) return
    const note = document.createElement("input")
    note.type = "hidden"
    note.name = "note"
    note.value = "1"
    event.target.append(note)
  }
}
