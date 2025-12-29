import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["card", "front", "back", "quantity", "foilQuantity"]
  static values = { 
    flipped: { type: Boolean, default: false },
    cardSetId: Number
  }

  connect() {
    // Listen for clicks outside to close
    this.outsideClickHandler = this.handleOutsideClick.bind(this)
  }

  disconnect() {
    document.removeEventListener("click", this.outsideClickHandler)
  }

  flip(event) {
    // Don't flip if clicking on inputs
    if (event.target.tagName === "INPUT") return
    
    this.flippedValue = !this.flippedValue
    this.cardTarget.style.transform = this.flippedValue ? "rotateY(180deg)" : "rotateY(0deg)"
    
    if (this.flippedValue) {
      document.addEventListener("click", this.outsideClickHandler)
      // Focus the quantity input
      setTimeout(() => this.quantityTarget?.focus(), 300)
    } else {
      document.removeEventListener("click", this.outsideClickHandler)
    }
  }

  handleOutsideClick(event) {
    if (!this.element.contains(event.target) && this.flippedValue) {
      this.flipBack()
    }
  }

  flipBack() {
    this.flippedValue = false
    this.cardTarget.style.transform = "rotateY(0deg)"
    document.removeEventListener("click", this.outsideClickHandler)
  }

  async save() {
    const cardId = this.element.dataset.cardId
    const quantity = this.quantityTarget.value || 0
    const foilQuantity = this.hasFoilQuantityTarget ? (this.foilQuantityTarget.value || 0) : 0

    try {
      const csrfToken = document.querySelector('[name="csrf-token"]')?.content
      const response = await fetch(`/card_sets/${this.cardSetIdValue}/update_card`, {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": csrfToken,
          Accept: "application/json"
        },
        body: JSON.stringify({
          card_id: cardId,
          quantity: quantity,
          foil_quantity: foilQuantity,
          notes: ""
        })
      })

      if (response.ok) {
        this.showSaveSuccess()
        // Update the front display
        this.updateFrontDisplay(quantity, foilQuantity)
      } else {
        this.showSaveError()
      }
    } catch (error) {
      console.error("Error saving:", error)
      this.showSaveError()
    }
  }

  updateFrontDisplay(quantity, foilQuantity) {
    const qty = parseInt(quantity) || 0
    const foilQty = parseInt(foilQuantity) || 0
    const isOwned = qty > 0 || foilQty > 0

    // Update card appearance
    const frontEl = this.frontTarget
    const img = frontEl.querySelector("img")
    
    if (isOwned) {
      frontEl.style.opacity = "1"
      if (img) img.style.filter = "none"
    } else {
      frontEl.style.opacity = "0.35"
      if (img) img.style.filter = "grayscale(100%)"
    }

    // Update quantity badges
    let badgeContainer = frontEl.querySelector(".quantity-badges")
    if (!badgeContainer) {
      badgeContainer = document.createElement("div")
      badgeContainer.className = "quantity-badges"
      badgeContainer.style.cssText = "position:absolute;top:4px;right:4px;display:flex;gap:2px;"
      frontEl.appendChild(badgeContainer)
    }

    badgeContainer.innerHTML = ""
    if (qty > 0) {
      badgeContainer.innerHTML += `<div style="background:rgba(0,0,0,0.8);color:#4f8;padding:2px 6px;border-radius:3px;font-size:11px;font-weight:600;">x${qty}</div>`
    }
    if (foilQty > 0) {
      badgeContainer.innerHTML += `<div style="background:linear-gradient(135deg, rgba(80,60,120,0.9) 0%, rgba(40,30,80,0.9) 100%);color:#c9f;padding:2px 6px;border-radius:3px;font-size:11px;font-weight:600;">x${foilQty}</div>`
    }
  }

  showSaveSuccess() {
    this.backTarget.style.boxShadow = "0 0 0 2px #4f8"
    setTimeout(() => {
      this.backTarget.style.boxShadow = "none"
      this.flipBack()
    }, 500)
  }

  showSaveError() {
    this.backTarget.style.boxShadow = "0 0 0 2px #f44"
    setTimeout(() => this.backTarget.style.boxShadow = "none", 1500)
  }
}
