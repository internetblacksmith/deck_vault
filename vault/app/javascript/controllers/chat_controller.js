import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="chat"
export default class extends Controller {
  static targets = ["messages", "input", "sendButton", "history"]

  connect() {
    this.scrollToBottom()
  }

  async send(event) {
    event.preventDefault()

    const message = this.inputTarget.value.trim()
    if (!message) return

    // Clear input and disable button
    this.inputTarget.value = ""
    this.sendButtonTarget.disabled = true

    // Add user message to UI
    this.addMessage(message, "user")

    // Show loading indicator
    const loadingEl = this.addLoadingMessage()

    try {
      const history = this.getHistory()
      
      const response = await fetch("/chat", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": this.getCSRFToken(),
          "Accept": "application/json"
        },
        body: JSON.stringify({
          message: message,
          history: JSON.stringify(history)
        })
      })

      const data = await response.json()

      // Remove loading indicator
      loadingEl.remove()

      // Add assistant response
      this.addMessage(data.response, "assistant")

      // Update conversation history
      this.updateHistory(data.history)

    } catch (error) {
      console.error("Chat error:", error)
      loadingEl.remove()
      this.addMessage("Sorry, something went wrong. Please try again.", "assistant")
    } finally {
      this.sendButtonTarget.disabled = false
      this.inputTarget.focus()
    }
  }

  addMessage(content, role) {
    const messageDiv = document.createElement("div")
    messageDiv.className = `message ${role}`

    const contentDiv = document.createElement("div")
    contentDiv.className = "message-content"
    contentDiv.innerHTML = this.formatMessage(content)

    messageDiv.appendChild(contentDiv)
    this.messagesTarget.appendChild(messageDiv)
    this.scrollToBottom()

    return messageDiv
  }

  addLoadingMessage() {
    const messageDiv = document.createElement("div")
    messageDiv.className = "message assistant loading"

    const contentDiv = document.createElement("div")
    contentDiv.className = "message-content"
    contentDiv.innerHTML = `
      <div class="loading-dots">
        <span></span>
        <span></span>
        <span></span>
      </div>
    `

    messageDiv.appendChild(contentDiv)
    this.messagesTarget.appendChild(messageDiv)
    this.scrollToBottom()

    return messageDiv
  }

  formatMessage(text) {
    if (!text) return ""

    // Escape HTML first
    let formatted = text
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")

    // Format code blocks (triple backticks)
    formatted = formatted.replace(/```(\w*)\n?([\s\S]*?)```/g, (match, lang, code) => {
      return `<pre><code>${code.trim()}</code></pre>`
    })

    // Format inline code (single backticks)
    formatted = formatted.replace(/`([^`]+)`/g, "<code>$1</code>")

    // Format bold (**text**)
    formatted = formatted.replace(/\*\*([^*]+)\*\*/g, "<strong>$1</strong>")

    // Format italic (*text*)
    formatted = formatted.replace(/\*([^*]+)\*/g, "<em>$1</em>")

    // Format bullet lists
    formatted = formatted.replace(/^[•\-\*]\s+(.+)$/gm, "<li>$1</li>")
    formatted = formatted.replace(/(<li>.*<\/li>)/s, "<ul>$1</ul>")

    // Format numbered lists
    formatted = formatted.replace(/^\d+\.\s+(.+)$/gm, "<li>$1</li>")

    // Convert newlines to <br> (but not in pre blocks)
    formatted = formatted.replace(/\n/g, "<br>")

    return formatted
  }

  scrollToBottom() {
    this.messagesTarget.scrollTop = this.messagesTarget.scrollHeight
  }

  getHistory() {
    try {
      return JSON.parse(this.historyTarget.value || "[]")
    } catch {
      return []
    }
  }

  updateHistory(history) {
    // Simplify history for storage - just keep role and text content
    const simplified = history.map(msg => {
      if (typeof msg.content === "string") {
        return msg
      }
      // For complex content (tool use responses), extract text
      if (Array.isArray(msg.content)) {
        const textContent = msg.content.find(c => c.type === "text")
        if (textContent) {
          return { role: msg.role, content: textContent.text }
        }
      }
      return msg
    })
    this.historyTarget.value = JSON.stringify(simplified)
  }

  getCSRFToken() {
    const meta = document.querySelector('meta[name="csrf-token"]')
    return meta ? meta.content : ""
  }
}
