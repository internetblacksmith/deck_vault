import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["cardImage", "flipButton"]
  static values = {
    isDfc: { type: Boolean, default: false },
    showingBack: { type: Boolean, default: false },
    frontImage: String,
    backImage: String
  }

  flipCard(event) {
    event.preventDefault()
    event.stopPropagation()

    if (!this.isDfcValue || !this.hasCardImageTarget) return

    this.showingBackValue = !this.showingBackValue

    if (this.showingBackValue && this.backImageValue) {
      this.cardImageTarget.src = this.backImageValue
    } else {
      this.cardImageTarget.src = this.frontImageValue || "/card_placeholder.webp"
    }

    // Update flip button appearance
    if (this.hasFlipButtonTarget) {
      if (this.showingBackValue) {
        this.flipButtonTarget.style.background = "rgba(40, 100, 180, 0.85)"
        this.flipButtonTarget.dataset.showing = "back"
      } else {
        this.flipButtonTarget.style.background = "rgba(0,0,0,0.75)"
        this.flipButtonTarget.dataset.showing = "front"
      }
    }
  }
}
