import { Controller } from "@hotwired/stimulus"

// Settings › Schedule: a schedule's first time zone is the GM's browser's,
// added to the list if it isn't one of Rails' named zones.
export default class extends Controller {
  static values = { fill: Boolean }

  connect() {
    if (!this.fillValue) return

    const zone = Intl.DateTimeFormat().resolvedOptions().timeZone
    if (!zone) return
    if (![...this.element.options].some((option) => option.value === zone)) this.element.add(new Option(zone, zone), 0)
    this.element.value = zone
  }
}
