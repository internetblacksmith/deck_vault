import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["toggle"]

  connect() {
    this.loadPreference()
    this.updateButton()
  }

  toggle() {
    const isDark = document.documentElement.classList.contains("dark")
    if (isDark) {
      document.documentElement.classList.remove("dark")
      localStorage.setItem("darkMode", "false")
    } else {
      document.documentElement.classList.add("dark")
      localStorage.setItem("darkMode", "true")
    }
    this.updateButton()
  }

  loadPreference() {
    const darkMode = localStorage.getItem("darkMode")
    const prefersDark = window.matchMedia(
      "(prefers-color-scheme: dark)"
    ).matches
    const shouldBeDark = darkMode === "true" || (darkMode === null && prefersDark)

    if (shouldBeDark) {
      document.documentElement.classList.add("dark")
    } else {
      document.documentElement.classList.remove("dark")
    }
  }

  updateButton() {
    const isDark = document.documentElement.classList.contains("dark")
    if (this.hasToggleTarget) {
      this.toggleTarget.textContent = isDark ? "☀️" : "🌙"
      this.toggleTarget.setAttribute("aria-label", isDark ? "Light mode" : "Dark mode")
    }
  }
}
