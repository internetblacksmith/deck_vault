import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["content", "icon"]

  connect() {
    // Collapsed by default
    this.collapsed = true
    this.contentTarget.style.display = "none"
  }

  toggle() {
    this.collapsed = !this.collapsed
    this.contentTarget.style.display = this.collapsed ? "none" : ""
    this.iconTarget.textContent = this.collapsed ? "+" : "-"
  }
}
