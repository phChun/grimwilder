import { Controller } from "@hotwired/stimulus"

// The talent picker (characters/talents/new): each card's Add toggle is a
// checkbox in the Taken panel's form. This keeps the panel's list in the order
// talents were taken, counts them against the limit (Save is off when over),
// and on a phone opens the panel as a drawer from its button. Each taken talent
// shows its summary under its name, so the list can be compared at a glance.
export default class extends Controller {
  static targets = ["box", "list", "count", "save", "over", "empty", "fab", "fabCount", "removeIcon"]
  static values = { limit: Number }

  connect() {
    this.order = [...this.listTarget.querySelectorAll("[data-key]")].map((item) => item.dataset.key)
    this.update()
  }

  update() {
    const chosen = new Map(this.boxTargets.filter((box) => box.checked).map((box) => [box.value, box.dataset]))
    this.order = this.order.filter((key) => chosen.has(key)).concat([...chosen.keys()].filter((key) => !this.order.includes(key)))

    this.listTarget.replaceChildren(...this.order.map((key) => this.item(key, chosen.get(key))))
    const count = `${chosen.size} of ${this.limitValue}`
    this.countTarget.textContent = count
    this.fabCountTarget.textContent = count
    this.emptyTarget.hidden = chosen.size > 0

    const over = chosen.size - this.limitValue
    this.overTarget.hidden = over <= 0
    this.overTarget.textContent = over > 0 ? `${over} more than there's room for: remove ${over === 1 ? "one" : over}.` : ""
    this.saveTarget.disabled = over > 0
  }

  remove(event) {
    const box = this.boxTargets.find((candidate) => candidate.value === event.currentTarget.dataset.key)
    if (box) box.checked = false
    this.update()
  }

  toggle() {
    const open = this.element.classList.toggle("talent-picker--open")
    this.fabTarget.setAttribute("aria-expanded", open)
  }

  item(key, { name, summary }) {
    const li = document.createElement("li")
    li.className = "talent-picker__item"
    li.dataset.key = key
    const label = document.createElement("span")
    label.className = "talent-picker__label"
    label.append(this.span("talent-picker__name", name))
    if (summary) label.append(this.span("talent-picker__summary", summary))
    const button = document.createElement("button")
    button.type = "button"
    button.className = "talent-picker__remove"
    button.dataset.key = key
    button.dataset.action = "talent-picker#remove"
    button.setAttribute("aria-label", `Remove ${name}`)
    button.append(this.removeIconTarget.content.cloneNode(true))
    li.append(label, button)
    return li
  }

  span(className, text) {
    const span = document.createElement("span")
    span.className = className
    span.textContent = text
    return span
  }
}
