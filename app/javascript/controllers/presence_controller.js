import { Controller } from "@hotwired/stimulus"
import { cable } from "@hotwired/turbo-rails"

// Presence halos on the faces at the top of the table rail
// ([data-presence-identity]): green for someone with the table open and in
// use, yellow for open but idle, none for no page open. This page checks in
// with PresenceChannel every BEAT, saying whether it's in use (input in the
// last IDLE_AFTER, in a visible tab), and paints what it hears about everyone.
// Someone not heard from for WINDOW (Membership::PRESENCE_WINDOW) loses their
// halo. Hovering a face shows its data-label ("Pip · idle") in a tooltip in
// the top layer (a manual popover), so nothing on the page can clip or cover it.
const BEAT = 30_000
const WINDOW = 75_000
const IDLE_AFTER = 120_000
const WORDS = { active: "at the table", idle: "idle" }

export default class extends Controller {
  static values = { campaign: Number }

  async connect() {
    this.heard = new Map() // identity id -> { presence, at }
    this.lastInput = Date.now()
    this.wasActive = true

    this.noteInput = this.noteInput.bind(this)
    for (const type of ["pointerdown", "keydown", "scroll", "visibilitychange"]) {
      document.addEventListener(type, this.noteInput, { passive: true, capture: true })
    }
    this.timer = setInterval(() => { this.checkIn(); this.paint() }, BEAT)
    this.observer = new MutationObserver(() => this.paint())
    this.observer.observe(this.element, { childList: true, subtree: true })

    this.tip = document.createElement("div")
    this.tip.className = "face-tip"
    this.tip.popover = "manual"
    this.tip.setAttribute("role", "tooltip")
    document.body.append(this.tip)
    this.showTip = this.showTip.bind(this)
    this.hideTip = this.hideTip.bind(this)
    this.element.addEventListener("mouseover", this.showTip)
    this.element.addEventListener("mouseout", this.hideTip)
    window.addEventListener("scroll", this.hideTip, { passive: true, capture: true })

    this.subscription = await cable.subscribeTo(
      { channel: "PresenceChannel", campaign_id: this.campaignValue },
      { connected: () => this.checkIn(), received: (data) => this.received(data) }
    )
    if (!this.element.isConnected) this.subscription.unsubscribe()
  }

  disconnect() {
    for (const type of ["pointerdown", "keydown", "scroll", "visibilitychange"]) {
      document.removeEventListener(type, this.noteInput, { capture: true })
    }
    clearInterval(this.timer)
    this.observer?.disconnect()
    this.subscription?.unsubscribe()
    this.element.removeEventListener("mouseover", this.showTip)
    this.element.removeEventListener("mouseout", this.hideTip)
    window.removeEventListener("scroll", this.hideTip, { capture: true })
    this.tip.remove()
  }

  // Under the face, right-aligned to it, kept on screen.
  showTip(event) {
    const face = event.target.closest("[data-presence-identity]")
    if (!face || !this.element.contains(face)) return
    this.tipFace = face
    // A morph refresh drops nodes the server didn't render, this one included.
    if (!this.tip.isConnected) document.body.append(this.tip)
    this.tip.textContent = face.dataset.label
    if (!this.tip.matches(":popover-open")) this.tip.showPopover()
    const box = face.getBoundingClientRect()
    const left = Math.max(8, Math.min(box.right - this.tip.offsetWidth, window.innerWidth - this.tip.offsetWidth - 8))
    this.tip.style.left = `${left}px`
    this.tip.style.top = `${box.bottom + 6}px`
  }

  hideTip(event) {
    if (event?.type === "mouseout" && this.tipFace?.contains(event.relatedTarget)) return
    this.tipFace = null
    if (this.tip?.matches(":popover-open")) this.tip.hidePopover()
  }

  get active() {
    return document.visibilityState === "visible" && Date.now() - this.lastInput < IDLE_AFTER
  }

  // Back from idle: say so now rather than at the next beat.
  noteInput() {
    if (document.visibilityState !== "visible") return
    this.lastInput = Date.now()
    if (!this.wasActive) this.checkIn()
  }

  checkIn() {
    this.wasActive = this.active
    this.subscription?.perform("check_in", { active: this.wasActive })
  }

  received(data) {
    const now = Date.now()
    if (data.presences) {
      for (const [id, presence] of Object.entries(data.presences)) this.heard.set(String(id), { presence, at: now })
    } else {
      this.heard.set(String(data.identity_id), { presence: data.presence, at: now })
    }
    this.paint()
  }

  presenceOf(id) {
    const heard = this.heard.get(id)
    if (!heard || heard.presence === "away" || Date.now() - heard.at > WINDOW) return "away"
    return heard.presence
  }

  paint() {
    for (const face of this.element.querySelectorAll("[data-presence-identity]")) {
      const presence = this.presenceOf(face.dataset.presenceIdentity)
      if (face.dataset.presence === presence) continue
      face.dataset.presence = presence
      const name = face.dataset.presenceName
      face.dataset.label = WORDS[presence] ? `${name} · ${WORDS[presence]}` : name
      face.setAttribute("aria-label", face.dataset.label)
      if (face === this.tipFace) this.tip.textContent = face.dataset.label
    }
  }
}
