import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["panel"]
  static values = { open: Boolean }

  connect() {
    if (this.openValue) this.open()
  }

  open() {
    if (!this.panelTarget.open) this.panelTarget.showModal()
  }

  close() {
    this.panelTarget.close()
  }
}
