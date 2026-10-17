import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    url: String,
    type: String,
    id: Number
  }

  async toggle(event) {
    event.preventDefault()
    const token = document.querySelector("meta[name='csrf-token']")?.getAttribute("content")
    const body = new URLSearchParams({
      bookmarkable_type: this.typeValue,
      bookmarkable_id: String(this.idValue)
    })

    try {
      const response = await fetch(this.urlValue, {
        method: "POST",
        headers: {
          Accept: "application/json",
          "Content-Type": "application/x-www-form-urlencoded",
          "X-CSRF-Token": token
        },
        body
      })
      if (!response.ok) return
      const payload = await response.json()
      if (typeof payload.starred !== "boolean") return
      if (window.Turbo) window.Turbo.visit(window.location.href, { action: "replace" })
    } catch {
      // Leave the star unchanged when the request fails.
    }
  }
}
