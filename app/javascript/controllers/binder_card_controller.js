import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["card", "front", "editor", "quantity", "foilQuantity", "cardImage", "flipButton", "badges", "normalBadge", "foilBadge", "editButton"]
  static values = { 
    editorOpen: { type: Boolean, default: false },
    cardSetId: Number,
    isDfc: { type: Boolean, default: false },
    showingBack: { type: Boolean, default: false },
    frontImage: String,
    backImage: String
  }

  connect() {
    // Listen for clicks outside to close editor
    this.outsideClickHandler = this.handleOutsideClick.bind(this)
  }

  disconnect() {
    document.removeEventListener("click", this.outsideClickHandler)
  }

  // Toggle the editor overlay
  toggleEditor(event) {
    event.stopPropagation()
    
    if (this.editorOpenValue) {
      this.closeEditor()
    } else {
      this.openEditor()
    }
  }

  openEditor() {
    this.editorOpenValue = true
    if (this.hasEditorTarget) {
      this.editorTarget.style.display = "flex"
    }
    
    document.addEventListener("click", this.outsideClickHandler)
    // Focus the quantity input
    setTimeout(() => this.quantityTarget?.focus(), 100)
  }

  closeEditor() {
    this.editorOpenValue = false
    if (this.hasEditorTarget) {
      this.editorTarget.style.display = "none"
    }
    document.removeEventListener("click", this.outsideClickHandler)
  }

  // Flip between front and back face of DFC (not the editor)
  flipCard(event) {
    event.stopPropagation()
    
    if (!this.isDfcValue || !this.hasCardImageTarget) return
    
    this.showingBackValue = !this.showingBackValue
    
    if (this.showingBackValue && this.backImageValue) {
      this.cardImageTarget.src = this.backImageValue
    } else {
      this.cardImageTarget.src = this.frontImageValue || '/card_placeholder.webp'
    }
    
    // Update flip button appearance
    if (this.hasFlipButtonTarget) {
      if (this.showingBackValue) {
        this.flipButtonTarget.style.background = "#2864b4"
        this.flipButtonTarget.dataset.showing = "back"
      } else {
        this.flipButtonTarget.style.background = "#333"
        this.flipButtonTarget.dataset.showing = "front"
      }
    }
  }

  handleOutsideClick(event) {
    if (!this.element.contains(event.target) && this.editorOpenValue) {
      this.closeEditor()
    }
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
        this.updateDisplay(quantity, foilQuantity)
      } else {
        this.showSaveError()
      }
    } catch (error) {
      console.error("Error saving:", error)
      this.showSaveError()
    }
  }

  updateDisplay(quantity, foilQuantity) {
    const qty = parseInt(quantity) || 0
    const foilQty = parseInt(foilQuantity) || 0
    const isOwned = qty > 0 || foilQty > 0

    // Update card appearance (opacity/grayscale)
    const frontEl = this.frontTarget
    const img = frontEl.querySelector("img")
    
    if (isOwned) {
      frontEl.style.opacity = "1"
      if (img) img.style.filter = "none"
    } else {
      frontEl.style.opacity = "0.5"
      if (img) img.style.filter = "grayscale(100%)"
    }

    // Update quantity badges in the control bar
    if (this.hasBadgesTarget) {
      this.badgesTarget.innerHTML = ""
      
      if (qty > 0) {
        const normalBadge = document.createElement("div")
        normalBadge.style.cssText = "background:#1a3a1a;color:#4f8;padding:1px 5px;border-radius:3px;font-size:10px;font-weight:600;border:1px solid #2a4a2a;"
        normalBadge.textContent = `x${qty}`
        this.badgesTarget.appendChild(normalBadge)
      }
      
      if (foilQty > 0) {
        const foilBadge = document.createElement("div")
        foilBadge.style.cssText = "background:linear-gradient(135deg, #2a2a3a 0%, #1a1a2a 100%);color:#c9f;padding:1px 5px;border-radius:3px;font-size:10px;font-weight:600;border:1px solid #3a3a4a;"
        foilBadge.textContent = `x${foilQty}`
        this.badgesTarget.appendChild(foilBadge)
      }
    }
  }

  showSaveSuccess() {
    // Flash the editor with green glow
    if (this.hasEditorTarget) {
      const el = this.editorTarget
      el.style.transition = "box-shadow 0.3s ease-in-out"
      el.style.boxShadow = "inset 0 0 20px rgba(68, 255, 136, 0.4)"
      
      setTimeout(() => {
        el.style.boxShadow = "none"
      }, 600)
      
      setTimeout(() => {
        el.style.transition = ""
      }, 900)
    }
  }

  showSaveError() {
    // Flash the editor with red glow
    if (this.hasEditorTarget) {
      const el = this.editorTarget
      el.style.transition = "box-shadow 0.3s ease-in-out"
      el.style.boxShadow = "inset 0 0 20px rgba(255, 68, 68, 0.4)"
      
      setTimeout(() => {
        el.style.boxShadow = "none"
      }, 800)
      
      setTimeout(() => {
        el.style.transition = ""
      }, 1100)
    }
  }

  // Legacy method for compatibility with old openEditor action
  close(event) {
    event.stopPropagation()
    this.closeEditor()
  }
}
