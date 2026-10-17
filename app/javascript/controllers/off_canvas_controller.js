import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["panel", "backdrop", "button"]

  connect() {
    this.onKeydown = (event) => {
      if (event.key === "Escape") this.close()
    }
    this.onResize = () => {
      const desktop = window.matchMedia("(min-width: 768px)").matches
      if (desktop) this.close()
      else if (!this.panelTarget.classList.contains("is-open")) this.panelTarget.inert = true
    }
    document.addEventListener("keydown", this.onKeydown)
    window.addEventListener("resize", this.onResize)
    this.close()
  }

  disconnect() {
    document.removeEventListener("keydown", this.onKeydown)
    window.removeEventListener("resize", this.onResize)
    document.body.classList.remove("overflow-hidden")
  }

  toggle() {
    if (this.panelTarget.classList.contains("is-open")) this.close()
    else this.open()
  }

  open() {
    this.panelTarget.classList.add("is-open")
    this.backdropTarget.classList.add("is-open")
    this.buttonTarget.setAttribute("aria-expanded", "true")
    this.buttonTarget.setAttribute("aria-label", this.buttonTarget.dataset.labelClose)
    this.panelTarget.inert = false
    document.body.classList.add("overflow-hidden")
  }

  close() {
    this.panelTarget.classList.remove("is-open")
    this.backdropTarget.classList.remove("is-open")
    if (this.hasButtonTarget) {
      this.buttonTarget.setAttribute("aria-expanded", "false")
      this.buttonTarget.setAttribute("aria-label", this.buttonTarget.dataset.labelOpen)
    }
    this.panelTarget.inert = !window.matchMedia("(min-width: 768px)").matches
    document.body.classList.remove("overflow-hidden")
  }

  closeIfLink(event) {
    if (event.target.closest(".bookmark-link")) return
    if (event.target.closest("a, button")) this.close()
  }
}
