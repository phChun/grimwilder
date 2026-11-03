import { Controller } from "@hotwired/stimulus"

// The "Chat" button on a phone (campaigns/_table_rail): the rail drops below
// the page there, so this jumps down to it. It shows only while the rail sits
// below the page's main column (stacked, not beside it) and is out of view.
export default class extends Controller {
  static values = { rail: String }

  connect() {
    this.rail = document.getElementById(this.railValue)
    if (!this.rail) return
    this.inView = false
    this.observer = new IntersectionObserver(([entry]) => { this.inView = entry.isIntersecting; this.update() })
    this.observer.observe(this.rail)
    this.onResize = () => this.update()
    window.addEventListener("resize", this.onResize)
    this.element.addEventListener("click", (event) => this.jump(event))
    this.update()
  }

  disconnect() {
    this.observer?.disconnect()
    window.removeEventListener("resize", this.onResize)
  }

  // Stacked: the rail starts below where its neighbour (the main column) starts.
  get stacked() {
    const main = this.rail.closest(".fluid__rail")?.parentElement?.querySelector(".fluid__main")
    return main ? this.rail.getBoundingClientRect().top > main.getBoundingClientRect().top + 8 : false
  }

  update() {
    this.element.hidden = this.inView || !this.stacked
  }

  jump(event) {
    event.preventDefault()
    const reduce = window.matchMedia("(prefers-reduced-motion: reduce)").matches
    this.rail.scrollIntoView({ behavior: reduce ? "auto" : "smooth", block: "start" })
    this.rail.querySelector("textarea")?.focus({ preventScroll: true })
  }
}
