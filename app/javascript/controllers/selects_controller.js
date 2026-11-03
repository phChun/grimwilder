import { Controller } from "@hotwired/stimulus"

// Draws every <select> on the page as our own dropdown: a button in the
// field's style, and a list in a popover (the top layer, so dialogs and
// scrolling cards can't clip it) with a search box once there are enough
// options to need one. On the body, so it reaches every page and frame.
//
// The native select stays in the form, hidden, and stays the truth: choosing
// sets its value and fires input and change, so forms, Stimulus actions, herb
// bindings and the CSS that reads option:checked carry on as before. A select
// changed from code (select.value = …, its options rewritten, a morph) is
// noticed and redrawn. Leave one native with data-native; multiple and
// list-box selects are left alone.
const SEARCH_FROM = 8 // options before the list gets a search box
const ENHANCE = "select:not([multiple]):not([size]):not([data-native])"
const KEPT_ATTRIBUTES = ["class", "tabindex", "aria-hidden"]

export default class extends Controller {
  connect() {
    this.menus = new Map() // select -> SelectMenu
    this.scan()
    this.observer = new MutationObserver((records) => {
      if (records.some((record) => !record.target.closest?.(".select-trigger, .select-menu"))) this.schedule()
    })
    this.observer.observe(this.element, { childList: true, subtree: true, characterData: true, attributes: true, attributeFilter: ["selected", "disabled", "label", "class", "hidden"] })
    this.beforeCache = () => this.teardown()
    // A morph refresh keeps the button and list (data-turbo-permanent) and the
    // hidden select's own attributes, then has everything redrawn.
    this.keepAttributes = (event) => {
      if (this.menus.has(event.target) && KEPT_ATTRIBUTES.includes(event.detail.attributeName)) event.preventDefault()
    }
    this.morphed = () => this.scan()
    document.addEventListener("turbo:before-cache", this.beforeCache)
    document.addEventListener("turbo:before-morph-attribute", this.keepAttributes)
    document.addEventListener("turbo:morph", this.morphed)
  }

  disconnect() {
    this.observer.disconnect()
    document.removeEventListener("turbo:before-cache", this.beforeCache)
    document.removeEventListener("turbo:before-morph-attribute", this.keepAttributes)
    document.removeEventListener("turbo:morph", this.morphed)
    this.teardown()
  }

  schedule() {
    if (this.pending) return
    this.pending = requestAnimationFrame(() => {
      this.pending = null
      this.scan()
    })
  }

  // Enhances new selects, puts back what a morph took away, drops menus whose
  // select is gone, and brings every label up to date.
  scan() {
    for (const [select, menu] of this.menus) {
      if (!select.isConnected) {
        menu.destroy()
        this.menus.delete(select)
      }
    }
    this.element.querySelectorAll(".select-trigger").forEach((trigger) => {
      if (![...this.menus.values()].some((menu) => menu.trigger === trigger)) trigger.remove() // from a cached page
    })
    this.element.querySelectorAll(ENHANCE).forEach((select) => {
      let menu = this.menus.get(select)
      if (!menu) this.menus.set(select, (menu = new SelectMenu(select)))
      menu.attach()
      menu.sync()
    })
  }

  // Back to plain selects, so a cached snapshot holds no menus of ours.
  teardown() {
    this.menus.forEach((menu) => menu.destroy())
    this.menus.clear()
  }
}

let counter = 0

class SelectMenu {
  constructor(select) {
    this.select = select
    this.uid = `select-menu-${++counter}`
    this.closedAt = -Infinity
    this.trigger = document.createElement("button")
    this.trigger.type = "button"
    this.trigger.setAttribute("aria-haspopup", "listbox")
    this.trigger.setAttribute("aria-expanded", "false")
    this.trigger.dataset.turboPermanent = ""
    this.trigger.innerHTML = `<span class="select-trigger__text"></span><svg class="select-trigger__chevron" viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M6 9l6 6 6-6"/></svg>`
    this.text = this.trigger.firstElementChild

    this.trigger.addEventListener("click", () => this.toggle())
    this.trigger.addEventListener("keydown", (event) => this.triggerKey(event))
    this.onChange = () => this.sync()
    this.onLabelClick = (event) => {
      if (event.target.closest("label")?.htmlFor !== this.select.id) return
      event.preventDefault()
      this.trigger.focus()
    }
    this.onReset = () => setTimeout(() => this.sync())
    select.addEventListener("change", this.onChange)
    document.addEventListener("click", this.onLabelClick)
    select.form?.addEventListener("reset", this.onReset)
    this.watchValue()
  }

  // Code that sets select.value or selectedIndex fires no event; the label
  // follows anyway.
  watchValue() {
    for (const property of ["value", "selectedIndex"]) {
      const native = Object.getOwnPropertyDescriptor(HTMLSelectElement.prototype, property)
      const menu = this
      Object.defineProperty(this.select, property, {
        configurable: true,
        get() { return native.get.call(this) },
        set(value) { native.set.call(this, value); menu.sync() }
      })
    }
  }

  // The select hidden and the button beside it, again after a morph took
  // either away.
  attach() {
    const select = this.select
    if (this.panel && !this.panel.isConnected) this.closed({ focus: false })
    if (!select.classList.contains("select-native")) select.classList.add("select-native")
    if (select.getAttribute("tabindex") !== "-1") select.setAttribute("tabindex", "-1")
    if (select.getAttribute("aria-hidden") !== "true") select.setAttribute("aria-hidden", "true")
    if (this.trigger.previousElementSibling !== select) select.after(this.trigger)
  }

  sync() {
    const select = this.select
    const classes = ["select-trigger", ...[...select.classList].filter((name) => name !== "select-native")].join(" ")
    if (this.trigger.className !== classes) this.trigger.className = classes
    const option = select.selectedOptions[0]
    const text = option ? optionText(option) : ""
    if (this.text.textContent !== text) this.text.textContent = text
    this.trigger.disabled = select.disabled
    this.trigger.hidden = select.hidden
    const name = select.getAttribute("aria-label") || [...(select.labels || [])].map((label) => label.textContent.trim()).join(" ")
    const label = name ? `${name}: ${text}` : text
    if (this.trigger.getAttribute("aria-label") !== label) this.trigger.setAttribute("aria-label", label)
    if (this.panel?.isConnected && this.signature() !== this.rendered) this.renderOptions()
  }

  // What the open list shows, to redraw it only when that changes (the
  // feed rewrites its options' labels as unread lines come and go).
  signature() {
    return [...this.select.options].map((option) => [option.value, optionText(option), option.selected, option.disabled, option.hidden].join("\u0001")).join("\u0002")
  }

  destroy() {
    this.close({ focus: false })
    this.trigger.remove()
    this.select.removeEventListener("change", this.onChange)
    document.removeEventListener("click", this.onLabelClick)
    this.select.form?.removeEventListener("reset", this.onReset)
    delete this.select.value
    delete this.select.selectedIndex
    this.select.classList.remove("select-native")
    this.select.removeAttribute("tabindex")
    this.select.removeAttribute("aria-hidden")
  }

  triggerKey(event) {
    if (["ArrowDown", "ArrowUp", "Enter", " "].includes(event.key)) {
      event.preventDefault()
      this.open()
    } else if (event.key.length === 1 && !event.metaKey && !event.ctrlKey && !event.altKey) {
      // Typing on the closed menu starts a search (or jumps to a match).
      event.preventDefault()
      this.open(event.key)
    }
  }

  // A click on the button while it's open: the popover's light dismiss has
  // already closed it on pointerdown, so this mustn't open it again.
  toggle() {
    if (this.panel?.isConnected) this.close()
    else if (performance.now() - this.closedAt > 250) this.open()
  }

  open(typed = "") {
    if (this.select.disabled || this.panel?.isConnected) return
    const searchable = this.select.options.length >= SEARCH_FROM

    this.panel = document.createElement("div")
    this.panel.className = "select-menu"
    this.panel.popover = "auto"
    this.panel.dataset.turboPermanent = ""
    this.panel.innerHTML = `
      ${searchable ? `<input type="search" class="select-menu__search" placeholder="Search" autocomplete="off" spellcheck="false" role="combobox" aria-autocomplete="list" aria-expanded="true" aria-controls="${this.uid}-list">` : ""}
      <ul class="select-menu__list" id="${this.uid}-list" role="listbox" tabindex="-1"></ul>
      <p class="select-menu__empty" hidden>No matches</p>`
    this.search = this.panel.querySelector(".select-menu__search")
    this.list = this.panel.querySelector(".select-menu__list")
    this.empty = this.panel.querySelector(".select-menu__empty")
    if (this.trigger.getAttribute("aria-label")) this.list.setAttribute("aria-label", this.trigger.getAttribute("aria-label").split(":")[0])

    // In a <dialog>, the list goes in it, so the dialog's focus trap and
    // light-dismiss leave it be; the popover's top layer still lifts it out.
    ;(this.trigger.closest("dialog") || document.body).append(this.panel)
    this.panel.addEventListener("toggle", (event) => { if (event.newState === "closed") this.closed() })
    this.panel.addEventListener("keydown", (event) => this.panelKey(event))
    this.list.addEventListener("click", (event) => {
      const item = event.target.closest("[role=option]")
      if (item && item.getAttribute("aria-disabled") !== "true") this.choose(item.dataset.index)
    })
    this.list.addEventListener("mousemove", (event) => {
      const item = event.target.closest("[role=option]")
      if (item && item !== this.active && item.getAttribute("aria-disabled") !== "true") this.activate(item, { scroll: false })
    })
    this.search?.addEventListener("input", () => this.filter())

    this.renderOptions()
    this.panel.showPopover()
    this.trigger.setAttribute("aria-expanded", "true")
    this.place()
    this.onViewport = () => this.place()
    window.addEventListener("resize", this.onViewport)
    window.addEventListener("scroll", this.onViewport, true)

    if (this.search) {
      this.search.value = typed
      this.search.focus()
      this.filter()
    } else {
      this.list.focus()
      if (typed) this.jumpTo(typed)
    }
  }

  close({ focus = true } = {}) {
    if (!this.panel?.isConnected || !this.panel.matches(":popover-open")) return
    this.refocus = focus
    this.panel.hidePopover()
  }

  // However it closed: a choice, Escape, a click outside, a morph.
  closed({ focus } = {}) {
    if (!this.panel) return
    if (focus === false) this.refocus = false
    this.closedAt = performance.now()
    window.removeEventListener("resize", this.onViewport)
    window.removeEventListener("scroll", this.onViewport, true)
    this.trigger.setAttribute("aria-expanded", "false")
    this.panel.remove()
    this.panel = this.active = null
    if (this.refocus !== false && this.trigger.isConnected) this.trigger.focus()
    this.refocus = true
  }

  renderOptions() {
    this.rendered = this.signature()
    const items = []
    let group = null
    ;[...this.select.options].forEach((option, index) => {
      if (option.hidden) return
      const parent = option.parentElement.tagName === "OPTGROUP" ? option.parentElement : null
      if (parent !== group) {
        group = parent
        if (parent) items.push(`<li class="select-menu__group" role="presentation">${escapeHtml(parent.label)}</li>`)
      }
      const disabled = option.disabled || parent?.disabled
      items.push(`<li id="${this.uid}-${index}" class="select-menu__option" role="option" data-index="${index}" data-search="${escapeHtml(`${optionText(option)} ${option.value}`)}" aria-selected="${option.selected}"${disabled ? ` aria-disabled="true"` : ""}>${escapeHtml(optionText(option))}</li>`)
    })
    this.list.innerHTML = items.join("")
    if (this.search) this.filter()
    else this.activate(this.list.querySelector("[aria-selected=true]") || this.enabledItems()[0])
  }

  filter() {
    const query = this.search.value
    const groups = new Map()
    let shown = 0
    this.list.querySelectorAll("li").forEach((item) => {
      if (item.getAttribute("role") === "presentation") {
        groups.set(item, false)
        this.lastGroup = item
        return
      }
      const match = matches(item.dataset.search, query)
      item.hidden = !match
      if (match) {
        shown++
        if (this.lastGroup) groups.set(this.lastGroup, true)
      }
    })
    this.lastGroup = null
    groups.forEach((visible, header) => { header.hidden = !visible })
    this.empty.hidden = shown > 0
    const items = this.enabledItems()
    this.activate((!query && this.list.querySelector("[aria-selected=true]:not([hidden])")) || items[0])
  }

  enabledItems() {
    return [...this.list.querySelectorAll("[role=option]:not([hidden]):not([aria-disabled=true])")]
  }

  activate(item, { scroll = true } = {}) {
    this.active?.classList.remove("select-menu__option--active")
    this.active = item || null
    const owner = this.search || this.list
    if (!item) return owner.removeAttribute("aria-activedescendant")
    item.classList.add("select-menu__option--active")
    owner.setAttribute("aria-activedescendant", item.id)
    if (scroll) item.scrollIntoView({ block: "nearest" })
  }

  move(by) {
    const items = this.enabledItems()
    if (!items.length) return
    const at = items.indexOf(this.active)
    this.activate(items[Math.min(items.length - 1, Math.max(0, at + by))])
  }

  // Without a search box, typing jumps to the first option starting with it.
  jumpTo(typed) {
    clearTimeout(this.typedTimer)
    this.typed = (this.typed || "") + typed.toLowerCase()
    this.typedTimer = setTimeout(() => { this.typed = "" }, 700)
    const item = this.enabledItems().find((candidate) => normalize(candidate.textContent).startsWith(normalize(this.typed)))
    if (item) this.activate(item)
  }

  panelKey(event) {
    switch (event.key) {
      case "ArrowDown": event.preventDefault(); this.move(1); break
      case "ArrowUp": event.preventDefault(); this.move(-1); break
      case "PageDown": event.preventDefault(); this.move(8); break
      case "PageUp": event.preventDefault(); this.move(-8); break
      case "Home": if (!this.search) { event.preventDefault(); this.move(-Infinity) } break
      case "End": if (!this.search) { event.preventDefault(); this.move(Infinity) } break
      case "Enter":
        event.preventDefault()
        if (this.active) this.choose(this.active.dataset.index)
        break
      case "Tab": this.close({ focus: false }); break
      default:
        if (!this.search && event.key.length === 1 && !event.metaKey && !event.ctrlKey && !event.altKey) this.jumpTo(event.key)
    }
  }

  choose(index) {
    const option = this.select.options[Number(index)]
    this.close()
    if (!option || option.selected) return
    option.selected = true
    this.sync()
    this.select.dispatchEvent(new Event("input", { bubbles: true }))
    this.select.dispatchEvent(new Event("change", { bubbles: true }))
  }

  // Under the button, or above it when there's more room there; as wide as
  // the button at least, kept on screen.
  place() {
    if (!this.panel?.isConnected) return
    const rect = this.trigger.getBoundingClientRect()
    const gap = 4
    const margin = 8
    const below = window.innerHeight - rect.bottom - gap - margin
    const above = rect.top - gap - margin
    const style = this.panel.style
    style.minWidth = `${Math.max(rect.width, 192)}px`
    style.maxWidth = `${window.innerWidth - margin * 2}px`
    const natural = this.panel.scrollHeight
    const upward = natural > below && above > below
    style.maxHeight = `${Math.max(160, Math.min(400, upward ? above : below))}px`
    const width = this.panel.offsetWidth
    style.left = `${Math.min(Math.max(margin, rect.left), window.innerWidth - width - margin)}px`
    style.top = upward ? "" : `${rect.bottom + gap}px`
    style.bottom = upward ? `${window.innerHeight - rect.top + gap}px` : ""
  }
}

// What an option shows: its label or its text.
function optionText(option) {
  return (option.label || option.textContent).trim()
}

function normalize(text) {
  return text.normalize("NFD").replace(/[̀-ͯ]/g, "").toLowerCase().replace(/[_/]+/g, " ")
}

// Every word of the query appears somewhere in the text (an option's label
// and value), ignoring case and accents ("new york" finds America/New_York).
export function matches(text, query) {
  const haystack = normalize(text)
  return normalize(query).split(/\s+/).filter(Boolean).every((word) => haystack.includes(word))
}

function escapeHtml(text) {
  return text.replace(/[&<>"']/g, (char) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[char])
}
