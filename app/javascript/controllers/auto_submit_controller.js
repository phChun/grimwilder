import { Controller } from "@hotwired/stimulus"

// Submits its form when a control changes (an admin list's filter dropdown),
// so there's no extra button to press.
export default class extends Controller {
  submit() {
    this.element.requestSubmit()
  }
}
