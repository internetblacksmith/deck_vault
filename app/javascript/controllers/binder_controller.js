import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["spread", "pageIndicator", "prevBtn", "nextBtn"]
  static values = { 
    currentSpread: { type: Number, default: 0 },
    totalSpreads: Number,
    cardsPerPage: Number
  }

  connect() {
    this.updateNavigation()
  }

  previousSpread() {
    if (this.currentSpreadValue > 0) {
      this.currentSpreadValue--
      this.showCurrentSpread()
    }
  }

  nextSpread() {
    if (this.currentSpreadValue < this.totalSpreadsValue - 1) {
      this.currentSpreadValue++
      this.showCurrentSpread()
    }
  }

  goToSpread(event) {
    const spread = parseInt(event.currentTarget.dataset.spread)
    if (spread >= 0 && spread < this.totalSpreadsValue) {
      this.currentSpreadValue = spread
      this.showCurrentSpread()
    }
  }

  showCurrentSpread() {
    // Hide all spreads
    this.spreadTargets.forEach((spread, index) => {
      spread.style.display = index === this.currentSpreadValue ? "flex" : "none"
    })
    this.updateNavigation()
  }

  updateNavigation() {
    // Update page indicator
    const leftPage = this.currentSpreadValue * 2 + 1
    const rightPage = leftPage + 1
    this.pageIndicatorTarget.textContent = `Pages ${leftPage}-${rightPage}`

    // Update button states
    this.prevBtnTarget.disabled = this.currentSpreadValue === 0
    this.nextBtnTarget.disabled = this.currentSpreadValue >= this.totalSpreadsValue - 1
    
    // Style disabled buttons
    this.prevBtnTarget.style.opacity = this.prevBtnTarget.disabled ? "0.3" : "1"
    this.nextBtnTarget.style.opacity = this.nextBtnTarget.disabled ? "0.3" : "1"
  }

  // Keyboard navigation
  keydown(event) {
    if (event.key === "ArrowLeft") {
      this.previousSpread()
    } else if (event.key === "ArrowRight") {
      this.nextSpread()
    }
  }
}
