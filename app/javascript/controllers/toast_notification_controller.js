import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    messages: Array
  }

  connect() {
    // Show any flash messages passed as data attributes
    if (this.hasMessagesValue && this.messagesValue.length > 0) {
      this.messagesValue.forEach((msg, index) => {
        // Stagger multiple toasts
        setTimeout(() => this.show(msg), index * 100)
      })
    }

    // Listen for programmatic toast:show events
    document.addEventListener("toast:show", (event) => this.show(event.detail))
  }

  show(detail) {
    const { message = "Action completed", type = "success", duration = 4000 } = detail

    const toast = document.createElement("div")
    toast.style.cssText = this.getToastStyles(type)
    toast.innerHTML = this.getToastHTML(message, type)

    this.element.appendChild(toast)

    // Animate in
    requestAnimationFrame(() => {
      toast.style.opacity = "1"
      toast.style.transform = "translateX(0)"
    })

    // Auto-dismiss
    setTimeout(() => this.dismiss(toast), duration)

    // Manual dismiss on click
    toast.addEventListener("click", () => this.dismiss(toast))
  }

  dismiss(toast) {
    toast.style.opacity = "0"
    toast.style.transform = "translateX(100%)"
    setTimeout(() => toast.remove(), 300)
  }

  getToastStyles(type) {
    const colors = {
      success: { bg: "#1a3a1a", border: "#2a5a2a", text: "#8f8" },
      error: { bg: "#3a1a1a", border: "#5a2a2a", text: "#f88" },
      info: { bg: "#1a2a3a", border: "#2a4a6a", text: "#8cf" },
      warning: { bg: "#3a3a1a", border: "#5a5a2a", text: "#ff8" }
    }
    const c = colors[type] || colors.info

    return `
      background: ${c.bg};
      border: 1px solid ${c.border};
      color: ${c.text};
      padding: 12px 16px;
      border-radius: 6px;
      margin-top: 8px;
      display: flex;
      align-items: center;
      gap: 12px;
      min-width: 280px;
      max-width: 400px;
      box-shadow: 0 4px 12px rgba(0,0,0,0.3);
      cursor: pointer;
      opacity: 0;
      transform: translateX(100%);
      transition: opacity 0.3s, transform 0.3s;
    `
  }

  getToastHTML(message, type) {
    const icons = {
      success: "&#10003;",
      error: "&#10007;",
      info: "&#8505;",
      warning: "&#9888;"
    }

    return `
      <span style="font-size:16px;font-weight:bold;">${icons[type] || icons.info}</span>
      <span style="flex:1;font-size:14px;">${this.escapeHtml(message)}</span>
      <span style="opacity:0.6;font-size:18px;">&times;</span>
    `
  }

  escapeHtml(text) {
    const div = document.createElement('div')
    div.textContent = text
    return div.innerHTML
  }
}
