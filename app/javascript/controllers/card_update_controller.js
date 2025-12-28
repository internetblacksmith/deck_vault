import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["quantity", "pageNumber", "notes"]

  connect() {
    // Add event listeners to all input fields for change events
    this.quantityTarget.addEventListener("change", () => this.submit())
    this.pageNumberTarget.addEventListener("change", () => this.submit())
    this.notesTarget.addEventListener("change", () => this.submit())
  }

  async submit() {
    const cardId = this.element.dataset.cardId
    const quantity = this.quantityTarget.value || 0
    const pageNumber = this.pageNumberTarget.value || null
    const notes = this.notesTarget.value || ""

    // Show loading state
    this.setLoading(true)

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
          page_number: pageNumber,
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
      this.quantityTarget.disabled = true
      this.pageNumberTarget.disabled = true
      this.notesTarget.disabled = true
    } else {
      this.element.classList.remove("opacity-60")
      this.quantityTarget.disabled = false
      this.pageNumberTarget.disabled = false
      this.notesTarget.disabled = false
    }
  }

  showSuccess() {
    // Remove any previous error/loading states
    this.element.classList.remove("bg-red-500/20")
    // Show brief success visual feedback
    this.element.classList.add("bg-green-500/20")
    setTimeout(() => this.element.classList.remove("bg-green-500/20"), 1500)
  }

  showError(message) {
    this.element.classList.remove("bg-green-500/20")
    this.element.classList.add("bg-red-500/20")
    console.error(message)
    setTimeout(() => this.element.classList.remove("bg-red-500/20"), 1500)
  }
}
