import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["panel"]

  connect() {
    // Close panel when clicking outside
    this.outsideClickHandler = this.handleOutsideClick.bind(this)
  }

  disconnect() {
    document.removeEventListener("click", this.outsideClickHandler)
  }

  toggle(event) {
    event.stopPropagation()
    const isVisible = this.panelTarget.style.display !== "none"
    
    if (isVisible) {
      this.hide()
    } else {
      this.show()
    }
  }

  show() {
    this.panelTarget.style.display = "block"
    // Add outside click listener after a small delay to avoid immediate close
    setTimeout(() => {
      document.addEventListener("click", this.outsideClickHandler)
    }, 10)
  }

  hide() {
    this.panelTarget.style.display = "none"
    document.removeEventListener("click", this.outsideClickHandler)
  }

  handleOutsideClick(event) {
    if (!this.element.contains(event.target)) {
      this.hide()
    }
  }
}
