import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["quantity", "foilQuantity", "notes"]

  connect() {
    // Add event listeners to all input fields for change events
    this.quantityTarget.addEventListener("change", () => this.submit())
    if (this.hasFoilQuantityTarget) {
      this.foilQuantityTarget.addEventListener("change", () => this.submit())
    }
    this.notesTarget.addEventListener("change", () => this.submit())
    
    // Listen for Turbo Frame load events
    this.element.addEventListener("turbo:submit-start", () => this.onSubmitStart())
    this.element.addEventListener("turbo:submit-end", () => this.onSubmitEnd())
  }

  async submit() {
    const cardId = this.element.dataset.cardId
    const quantity = this.quantityTarget.value || 0
    const foilQuantity = this.hasFoilQuantityTarget ? (this.foilQuantityTarget.value || 0) : 0
    const notes = this.notesTarget.value || ""

    // Show loading state
    this.setLoading(true)
    this.showSpinner()

    try {
      // Find the form's CSRF token from the document
      const csrfToken = document.querySelector('[name="csrf-token"]')?.content

      const response = await fetch(this.formAction(cardId), {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": csrfToken,
          Accept: "text/vnd.turbo-stream.html, text/html, application/xhtml+xml"
        },
        body: JSON.stringify({
          card_id: cardId,
          quantity: quantity,
          foil_quantity: foilQuantity,
          notes: notes
        })
      })

      if (!response.ok) {
        this.showError("Failed to save card")
        return
      }

      // Turbo automatically handles turbo-stream responses
      this.showSuccess()
    } catch (error) {
      console.error("Error saving card:", error)
      this.showError("Error saving card")
    } finally {
      this.setLoading(false)
      this.hideSpinner()
    }
  }

  formAction(cardId) {
    const setId = this.getCardSetId()
    return `/card_sets/${setId}/update_card`
  }

  getCardSetId() {
    // Get card set ID from the page data or DOM
    const progressElement = document.querySelector("[data-set-progress-set-id-value]")
    return progressElement?.dataset.setProgressSetIdValue
  }

  setLoading(isLoading) {
    // Add opacity and disable inputs during loading
    if (isLoading) {
      this.element.classList.add("opacity-60")
      // Disable visible inputs only (skip hidden inputs in binder view)
      const visibleInputs = this.element.querySelectorAll("input:not([type='hidden'])")
      visibleInputs.forEach(input => (input.disabled = true))
    } else {
      this.element.classList.remove("opacity-60")
      // Re-enable visible inputs
      const visibleInputs = this.element.querySelectorAll("input:not([type='hidden'])")
      visibleInputs.forEach(input => (input.disabled = false))
    }
  }

  showSpinner() {
    // Show loading spinner overlay
    if (this.element.classList.contains("group")) {
      // Grid/Binder card - add spinner to the card
      const spinner = document.createElement("div")
      spinner.className = "absolute inset-0 flex items-center justify-center bg-black/20 rounded-lg spinner-overlay"
      spinner.innerHTML = '<div class="animate-spin text-purple-400">⚙️</div>'
      this.element.style.position = "relative"
      this.element.appendChild(spinner)
    }
  }

  hideSpinner() {
    // Remove loading spinner
    const spinner = this.element.querySelector(".spinner-overlay")
    if (spinner) {
      spinner.remove()
    }
  }

  onSubmitStart() {
    this.showSpinner()
  }

  onSubmitEnd() {
    this.hideSpinner()
  }

  showSuccess() {
    // Remove any previous error/loading states
    this.element.classList.remove("bg-red-500/20")
    // Show brief success visual feedback
    this.element.classList.add("bg-green-500/20")
    setTimeout(() => this.element.classList.remove("bg-green-500/20"), 1500)
    
    // Dispatch toast notification
    this.dispatchToast("Card updated successfully", "success")
  }

  showError(message) {
    this.element.classList.remove("bg-green-500/20")
    this.element.classList.add("bg-red-500/20")
    console.error(message)
    setTimeout(() => this.element.classList.remove("bg-red-500/20"), 1500)
    
    // Dispatch toast notification
    this.dispatchToast(message || "Failed to update card", "error")
  }

  dispatchToast(message, type) {
    const event = new CustomEvent("toast:show", {
      detail: { message, type, duration: 4000 }
    })
    document.dispatchEvent(event)
  }
}
