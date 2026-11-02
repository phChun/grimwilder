import { Controller } from "@hotwired/stimulus"

// Shows a <time datetime="…"> in the viewer's own time zone ("8:41 PM").
// The server can't know it, and chat lines are rendered once for everyone.
//
// A game date (SchedulesHelper#game_time_tag) carries a style and the
// schedule's zone: the server already wrote it in that zone ("Tonight, 7pm
// EST"), so it's rewritten only for a viewer somewhere else, in the same
// words: short ("Tonight, 8pm"), date ("Sat Nov 14 · 8pm"), full ("Saturday,
// November 14 · 8pm") or relative ("tonight", "in 3 days").
export default class extends Controller {
  static values = { style: String, zone: String }

  connect() {
    this.render()
  }

  // Again after a Turbo morph, which puts the server's text back.
  render() {
    const date = new Date(this.element.getAttribute("datetime"))
    if (Number.isNaN(date.getTime())) return

    if (this.styleValue) {
      if (this.zoneValue === Intl.DateTimeFormat().resolvedOptions().timeZone) return
      this.element.textContent = gameText(date, this.styleValue, new Date())
    } else {
      this.element.textContent = date.toLocaleTimeString([], { hour: "numeric", minute: "2-digit" })
    }
    this.element.title = date.toLocaleString()
  }
}

function gameText(date, style, now) {
  const startOfDay = (d) => new Date(d.getFullYear(), d.getMonth(), d.getDate())
  const days = Math.round((startOfDay(date) - startOfDay(now)) / 86400000)
  const evening = date.getHours() >= 17

  if (style === "relative") {
    if (days === 0) return evening ? "tonight" : "today"
    return days === 1 ? "tomorrow" : `in ${days} days`
  }

  const clock = date.toLocaleTimeString("en-US", { hour: "numeric", minute: date.getMinutes() ? "2-digit" : undefined }).replace(/\s/g, "").toLowerCase()
  const weekday = date.toLocaleDateString("en-US", { weekday: "short" })
  const monthDay = date.toLocaleDateString("en-US", { month: "short", day: "numeric" })

  if (style === "short") {
    let day = `${weekday} ${monthDay}`
    if (days === 0) day = evening ? "Tonight" : "Today"
    else if (days === 1) day = "Tomorrow"
    else if (days >= 2 && days <= 6) day = weekday
    return `${day}, ${clock}`
  }
  if (style === "full") {
    return `${date.toLocaleDateString("en-US", { weekday: "long", month: "long", day: "numeric" })} · ${clock}`
  }
  return `${weekday} ${monthDay} · ${clock}`
}
