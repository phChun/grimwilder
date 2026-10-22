import { Controller } from "@hotwired/stimulus"

// The roll call modal (roll_calls/_call). It opens by itself whenever the call
// arrives or changes state, unless it was hidden: hiding is remembered for this
// tab by key (the call and its status), so later dice landing don't keep
// popping it back up. A waiting call leaves a pill to bring it back; a
// finished one is just closed.
export default class extends Controller {
  static targets = ["dialog", "pill"]
  static values = { key: String, done: Boolean }

  connect() {
    if (hidden().has(this.keyValue)) {
      this.showPill()
    } else {
      this.open()
    }
  }

  disconnect() {
    if (this.dialogTarget.open) this.dialogTarget.close()
  }

  open() {
    if (this.hasPillTarget) this.pillTarget.hidden = true
    if (!this.dialogTarget.open) this.dialogTarget.showModal()
  }

  reopen() {
    hidden().delete(this.keyValue)
    save()
    this.open()
  }

  hide(event) {
    event?.preventDefault()
    hidden().add(this.keyValue)
    save()
    this.dialogTarget.close()
    this.showPill()
  }

  showPill() {
    if (this.hasPillTarget) this.pillTarget.hidden = this.doneValue
  }
}

const STORAGE_KEY = "hidden-roll-calls"
let hiddenKeys

function hidden() {
  if (!hiddenKeys) {
    try { hiddenKeys = new Set(JSON.parse(sessionStorage.getItem(STORAGE_KEY)) || []) } catch { hiddenKeys = new Set() }
  }
  return hiddenKeys
}

function save() {
  try { sessionStorage.setItem(STORAGE_KEY, JSON.stringify([...hiddenKeys].slice(-20))) } catch {}
}
