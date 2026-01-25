import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["spread", "pageIndicator", "prevBtn", "nextBtn", "pageIndicatorDot"]
  static values = { 
    currentSpread: { type: Number, default: 0 },
    totalSpreads: Number,
    cardsPerPage: Number
  }

  connect() {
    this.updateNavigation()

    // Add global keyboard listener for arrow key navigation
    this.boundKeydown = this.globalKeydown.bind(this)
    document.addEventListener("keydown", this.boundKeydown)
  }

  disconnect() {
    // Remove global keyboard listener
    if (this.boundKeydown) {
      document.removeEventListener("keydown", this.boundKeydown)
    }
  }

  // Global keyboard handler - works without focus on binder element
  globalKeydown(event) {
    // Don't intercept if user is typing in an input/textarea
    if (event.target.tagName === "INPUT" || event.target.tagName === "TEXTAREA") {
      return
    }

    if (event.key === "ArrowLeft") {
      event.preventDefault()
      this.previousSpread()
    } else if (event.key === "ArrowRight") {
      event.preventDefault()
      this.nextSpread()
    }
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
    const spreadIndex = parseInt(event.currentTarget.dataset.spreadIndex)
    if (spreadIndex >= 0 && spreadIndex < this.totalSpreadsValue) {
      this.currentSpreadValue = spreadIndex
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
    // Update page indicator text from spread's data attribute or calculate
    const currentSpread = this.spreadTargets[this.currentSpreadValue]
    if (currentSpread && currentSpread.dataset.spreadLabel) {
      this.pageIndicatorTarget.textContent = currentSpread.dataset.spreadLabel
    } else if (this.currentSpreadValue === 0) {
      this.pageIndicatorTarget.textContent = "Cover"
    } else {
      // Fallback for spreads without explicit labels
      this.pageIndicatorTarget.textContent = `Spread ${this.currentSpreadValue + 1}`
    }

    // Update button states
    this.prevBtnTarget.disabled = this.currentSpreadValue === 0
    this.nextBtnTarget.disabled = this.currentSpreadValue >= this.totalSpreadsValue - 1
    
    // Style disabled buttons
    this.prevBtnTarget.style.opacity = this.prevBtnTarget.disabled ? "0.3" : "1"
    this.nextBtnTarget.style.opacity = this.nextBtnTarget.disabled ? "0.3" : "1"

    // Update page indicator buttons - highlight the current spread's buttons
    if (this.hasPageIndicatorDotTarget) {
      this.pageIndicatorDotTargets.forEach(dot => {
        const dotSpreadIndex = parseInt(dot.dataset.spreadIndex)
        const isActive = dotSpreadIndex === this.currentSpreadValue
        
        // Add/remove active styling
        if (isActive) {
          dot.style.transform = "scale(1.1)"
          dot.style.boxShadow = "0 0 8px rgba(255,255,255,0.4)"
          dot.style.outline = "2px solid rgba(255,255,255,0.6)"
          dot.style.outlineOffset = "1px"
        } else {
          dot.style.transform = "scale(1)"
          dot.style.boxShadow = "none"
          dot.style.outline = "none"
        }
      })
    }
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
