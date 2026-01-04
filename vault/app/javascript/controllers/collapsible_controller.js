import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["content", "icon"]

  connect() {
    // Collapsed by default
    this.collapsed = true
    this.contentTargets.forEach(target => {
      target.style.display = "none"
    })
  }

  toggle() {
    this.collapsed = !this.collapsed
    this.contentTargets.forEach(target => {
      // Use table-row for tr elements, block for others
      const displayType = target.tagName === "TR" ? "table-row" : "block"
      target.style.display = this.collapsed ? "none" : displayType
    })
    this.iconTarget.textContent = this.collapsed ? "+" : "-"
  }
}
