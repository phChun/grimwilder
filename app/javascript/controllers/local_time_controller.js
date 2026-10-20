import { Controller } from "@hotwired/stimulus"

// Shows a <time datetime="…"> in the viewer's own time zone ("8:41 PM").
// The server can't know it, and chat lines are rendered once for everyone.
export default class extends Controller {
  connect() {
    this.render()
  }

  // Again after a Turbo morph, which puts the server's text back.
  render() {
    const date = new Date(this.element.getAttribute("datetime"))
    if (Number.isNaN(date.getTime())) return

    this.element.textContent = date.toLocaleTimeString([], { hour: "numeric", minute: "2-digit" })
    this.element.title = date.toLocaleString()
  }
}
