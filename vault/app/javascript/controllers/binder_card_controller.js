import { Controller } from "@hotwired/stimulus"
import { subscribeToCardImage } from "channels/card_image"

export default class extends Controller {
  static targets = ["card", "front", "editor", "quantity", "foilQuantity", "cardImage", "flipButton", "badges", "normalBadge", "foilBadge", "editButton", "downloadButton", "newBadge"]
  static values = {
    editorOpen: { type: Boolean, default: false },
    cardSetId: Number,
    isDfc: { type: Boolean, default: false },
    showingBack: { type: Boolean, default: false },
    frontImage: String,
    backImage: String,
    downloading: { type: Boolean, default: false },
    needsPlacement: { type: Boolean, default: false }
  }

  connect() {
    // Listen for clicks outside to close editor
    this.outsideClickHandler = this.handleOutsideClick.bind(this)
    this.imageSubscription = null
  }

  disconnect() {
    document.removeEventListener("click", this.outsideClickHandler)
    // Clean up ActionCable subscription if active
    if (this.imageSubscription) {
      this.imageSubscription.unsubscribe()
      this.imageSubscription = null
    }
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

  async downloadImage(event) {
    event.stopPropagation()

    const button = event.currentTarget
    const cardId = this.element.dataset.cardId

    // Prevent double-clicks
    if (this.downloadingValue) return
    this.downloadingValue = true

    // Visual feedback - show loading state with orange glow
    button.innerHTML = "&#8635;"
    button.style.background = "#ffc107"
    button.style.borderColor = "#e0a800"
    button.disabled = true
    this.showDownloadingState()

    // Subscribe to ActionCable for real-time image updates
    this.imageSubscription = subscribeToCardImage(cardId, (data) => {
      this.handleImageReady(data, button)
    })

    try {
      const csrfToken = document.querySelector('[name="csrf-token"]')?.content
      const response = await fetch(`/card_sets/${this.cardSetIdValue}/download_card_image`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": csrfToken,
          Accept: "application/json"
        },
        body: JSON.stringify({
          card_id: cardId
        })
      })

      if (response.ok) {
        const data = await response.json()
        if (data.success) {
          // If image was already downloaded, update immediately
          if (data.image_path) {
            this.handleImageReady({
              image_path: data.image_path,
              back_image_path: data.back_image_path
            }, button)
          }
          // Otherwise, wait for ActionCable broadcast from background job
        } else {
          throw new Error(data.error || "Download failed")
        }
      } else {
        throw new Error(`HTTP ${response.status}`)
      }
    } catch (error) {
      console.error("Error downloading image:", error)
      this.handleDownloadError(button)
    }
  }

  handleImageReady(data, button) {
    // Update the card image
    if (data.image_path) {
      this.cardImageTarget.src = `/${data.image_path}`
      this.frontImageValue = `/${data.image_path}`
    }

    // Update back image for DFCs
    if (data.back_image_path) {
      this.backImageValue = `/${data.back_image_path}`
    }

    // Remove the download button
    if (button && button.parentNode) {
      button.remove()
    } else if (this.hasDownloadButtonTarget) {
      this.downloadButtonTarget.remove()
    }

    // Clear downloading state
    this.downloadingValue = false
    this.clearDownloadingState()
    this.showDownloadSuccess()

    // Unsubscribe from ActionCable
    if (this.imageSubscription) {
      this.imageSubscription.unsubscribe()
      this.imageSubscription = null
    }
  }

  handleDownloadError(button) {
    this.downloadingValue = false
    this.clearDownloadingState()
    this.showDownloadError()

    // Reset button
    if (button) {
      button.innerHTML = "&#x2193;"
      button.style.background = "#28a745"
      button.style.borderColor = "#4caf50"
      button.disabled = false
    }

    // Unsubscribe from ActionCable
    if (this.imageSubscription) {
      this.imageSubscription.unsubscribe()
      this.imageSubscription = null
    }
  }

  showDownloadingState() {
    // Show orange glow while downloading
    if (this.hasFrontTarget) {
      const el = this.frontTarget
      el.style.transition = "box-shadow 0.3s ease-in-out"
      el.style.boxShadow = "0 0 15px rgba(255, 193, 7, 0.8)"
      el.classList.add("downloading")
    }
  }

  clearDownloadingState() {
    if (this.hasFrontTarget) {
      const el = this.frontTarget
      el.style.boxShadow = "none"
      el.classList.remove("downloading")
    }
  }

  showDownloadSuccess() {
    // Flash the card with green glow
    if (this.hasFrontTarget) {
      const el = this.frontTarget
      el.style.transition = "box-shadow 0.3s ease-in-out"
      el.style.boxShadow = "0 0 20px rgba(68, 255, 136, 0.6)"

      setTimeout(() => {
        el.style.boxShadow = "none"
      }, 600)

      setTimeout(() => {
        el.style.transition = ""
      }, 900)
    }
  }

  showDownloadError() {
    // Flash the card with red glow
    if (this.hasFrontTarget) {
      const el = this.frontTarget
      el.style.transition = "box-shadow 0.3s ease-in-out"
      el.style.boxShadow = "0 0 20px rgba(255, 68, 68, 0.6)"

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

  // Mark card as physically placed in binder (clear needs_placement marker)
  async markPlaced(event) {
    event.stopPropagation()

    const cardId = this.element.dataset.cardId
    const button = event.currentTarget

    // Visual feedback - shrink and fade
    button.style.transition = "all 0.3s ease-out"
    button.style.transform = "scale(0.8)"
    button.style.opacity = "0.5"
    button.disabled = true

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
          clear_needs_placement: true
        })
      })

      if (response.ok) {
        // Animate badge removal
        button.style.transform = "scale(0)"
        button.style.opacity = "0"
        setTimeout(() => {
          button.remove()
          this.needsPlacementValue = false
          // Update the counter if it exists on the page
          this.updatePlacementCounter(-1)
        }, 300)
      } else {
        // Reset button on error
        button.style.transform = "scale(1)"
        button.style.opacity = "1"
        button.disabled = false
        this.showMarkPlacedError()
      }
    } catch (error) {
      console.error("Error marking card as placed:", error)
      button.style.transform = "scale(1)"
      button.style.opacity = "1"
      button.disabled = false
      this.showMarkPlacedError()
    }
  }

  showMarkPlacedError() {
    // Flash the badge red
    if (this.hasNewBadgeTarget) {
      const el = this.newBadgeTarget
      const originalBg = el.style.background
      el.style.background = "#c44"
      setTimeout(() => {
        el.style.background = originalBg
      }, 600)
    }
  }

  updatePlacementCounter(delta) {
    // Find and update the "Clear All" button counter if it exists
    const clearAllBtn = document.querySelector("[data-placement-count]")
    if (clearAllBtn) {
      const currentCount = parseInt(clearAllBtn.dataset.placementCount) || 0
      const newCount = Math.max(0, currentCount + delta)
      clearAllBtn.dataset.placementCount = newCount

      // Update button text
      const countSpan = clearAllBtn.querySelector("[data-count]")
      if (countSpan) {
        countSpan.textContent = newCount
      }

      // Hide button if no more cards need placement
      if (newCount === 0) {
        clearAllBtn.style.display = "none"
      }
    }
  }
}
