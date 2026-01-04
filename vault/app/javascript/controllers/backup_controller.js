import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["importPanel", "delverPanel"]

  toggleImport() {
    if (this.hasImportPanelTarget) {
      const isHidden = this.importPanelTarget.style.display === "none"
      this.importPanelTarget.style.display = isHidden ? "block" : "none"
      // Hide delver panel when showing import
      if (this.hasDelverPanelTarget && isHidden) {
        this.delverPanelTarget.style.display = "none"
      }
    }
  }

  toggleDelver() {
    if (this.hasDelverPanelTarget) {
      const isHidden = this.delverPanelTarget.style.display === "none"
      this.delverPanelTarget.style.display = isHidden ? "block" : "none"
      // Hide import panel when showing delver
      if (this.hasImportPanelTarget && isHidden) {
        this.importPanelTarget.style.display = "none"
      }
    }
  }
}
