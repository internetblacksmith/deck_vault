import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["importPanel"]

  toggleImport() {
    if (this.hasImportPanelTarget) {
      const isHidden = this.importPanelTarget.style.display === "none"
      this.importPanelTarget.style.display = isHidden ? "block" : "none"
    }
  }
}
