import { Controller } from "@hotwired/stimulus"

// Opens a page in the modal (shared/_frame_modal) as soon as it lands: the
// layout renders one when a redirect asked for it (flash[:open_modal]), as
// starting a scene with a story question does for the story roll. It loads
// the modal's frame, which opens once loaded, then removes itself.
export default class extends Controller {
  static values = { url: String }

  connect() {
    const frame = document.getElementById("modal")
    if (frame && this.urlValue) frame.src = this.urlValue
    this.element.remove()
  }
}
