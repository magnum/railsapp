import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["source", "status"]

  copy() {
    navigator.clipboard.writeText(this.sourceTarget.innerText).then(() => {
      this.statusTarget.textContent = this.element.dataset.clipboardCopied
    })
  }
}
