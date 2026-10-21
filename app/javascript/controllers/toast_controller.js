import { Controller } from "@hotwired/stimulus"

// A toast that goes away on its own: after `seconds` (counted by the server,
// so clocks don't matter), or when closed. Hovering or focusing it holds it.
// A sticky one stays until closed. A Turbo morph re-renders it with the
// server's markup, so after every morph this puts back whatever the person
// already did: a toast that's gone stays gone (closed ones are remembered for
// this tab by key). With `remove`, a toast leaves the page once it's gone
// (the failure toasts, which are data-turbo-permanent and would pile up).
export default class extends Controller {
  static values = { key: String, seconds: Number, sticky: Boolean, remove: Boolean }

  connect() {
    this.sync()
  }

  disconnect() {
    clearTimeout(this.timer)
  }

  keyValueChanged() {
    if (this.connected) this.sync()
  }

  sync() {
    this.connected = true
    if (this.key !== this.keyValue) {
      this.key = this.keyValue
      this.deadline = Date.now() + this.secondsValue * 1000
      this.held = false
    }

    if (closed().has(this.key) || (!this.stickyValue && Date.now() >= this.deadline)) return this.hide()
    this.element.hidden = false
    this.schedule()
  }

  pause() {
    this.held = true
    clearTimeout(this.timer)
  }

  resume() {
    if (this.element.contains(document.activeElement) || this.element.matches(":hover")) return
    this.held = false
    // Give a moment to read it again after letting go.
    this.deadline = Math.max(this.deadline, Date.now() + 5000)
    this.schedule()
  }

  close() {
    closed().add(this.key)
    save()
    this.hide()
  }

  schedule() {
    clearTimeout(this.timer)
    if (this.stickyValue || this.held) return
    this.timer = setTimeout(() => this.hide(), this.deadline - Date.now())
  }

  hide() {
    clearTimeout(this.timer)
    this.element.hidden = true
    if (this.removeValue) this.element.remove()
  }
}

const STORAGE_KEY = "closed-toasts"
let closedKeys

function closed() {
  if (!closedKeys) {
    try { closedKeys = new Set(JSON.parse(sessionStorage.getItem(STORAGE_KEY)) || []) } catch { closedKeys = new Set() }
  }
  return closedKeys
}

function save() {
  try { sessionStorage.setItem(STORAGE_KEY, JSON.stringify([...closedKeys].slice(-20))) } catch {}
}
