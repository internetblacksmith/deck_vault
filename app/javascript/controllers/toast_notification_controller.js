import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["container"]

  connect() {
    // Listen for toast:show events
    document.addEventListener("toast:show", (event) => this.show(event.detail))
  }

  /**
   * Show a toast notification
   * @param {Object} detail - Toast configuration
   * @param {string} detail.message - Toast message
   * @param {string} detail.type - Toast type: 'success', 'error', 'info', 'warning'
   * @param {number} detail.duration - Duration in ms (default: 4000)
   */
  show(detail) {
    const { message = "Action completed", type = "info", duration = 4000 } = detail

    // Create toast element
    const toast = document.createElement("div")
    toast.className = `toast-notification toast-${type} animate-fade-in`
    toast.innerHTML = this.getToastHTML(message, type)

    // Add to container
    const container = document.getElementById("toast-container")
    container.appendChild(toast)

    // Auto-dismiss after duration
    setTimeout(() => {
      toast.classList.add("animate-fade-out")
      setTimeout(() => toast.remove(), 300)
    }, duration)

    // Allow manual dismiss
    toast.querySelector("[data-action]")?.addEventListener("click", () => {
      toast.remove()
    })
  }

  getToastHTML(message, type) {
    const icons = {
      success: "✓",
      error: "✕",
      info: "ℹ",
      warning: "⚠"
    }

    const colors = {
      success: "bg-green-500/20 border-green-500/50 text-green-300",
      error: "bg-red-500/20 border-red-500/50 text-red-300",
      info: "bg-blue-500/20 border-blue-500/50 text-blue-300",
      warning: "bg-yellow-500/20 border-yellow-500/50 text-yellow-300"
    }

    return `
      <div class="flex items-center justify-between gap-4 p-4 rounded-lg border ${colors[type]} backdrop-blur-sm">
        <div class="flex items-center gap-3">
          <span class="text-lg font-bold">${icons[type]}</span>
          <p class="text-sm">${message}</p>
        </div>
        <button type="button" aria-label="Close notification" class="text-lg hover:opacity-70 transition" data-action="click->toast-notification#close">
          ×
        </button>
      </div>
    `
  }

  close(event) {
    const toast = event.target.closest(".toast-notification")
    toast.classList.add("animate-fade-out")
    setTimeout(() => toast.remove(), 300)
  }
}
