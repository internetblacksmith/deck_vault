import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["fileInput", "form", "modal", "modalContent", "loading"]
  static values = {
    previewUrl: String,
    importUrl: String
  }

  connect() {
    // Bind escape key handler
    this.handleKeydown = this.handleKeydown.bind(this)
    document.addEventListener("keydown", this.handleKeydown)
  }

  disconnect() {
    document.removeEventListener("keydown", this.handleKeydown)
  }

  handleKeydown(event) {
    if (event.key === "Escape" && this.hasModalTarget && this.modalTarget.style.display !== "none") {
      this.closeModal()
    }
  }

  async preview(event) {
    event.preventDefault()

    const files = this.fileInputTarget.files
    if (files.length === 0) {
      this.showToast("Please select at least one CSV file", "error")
      return
    }

    // Show loading state
    this.showLoading()

    const formData = new FormData()
    for (let i = 0; i < files.length; i++) {
      formData.append("csv_files[]", files[i])
    }

    try {
      const response = await fetch(this.previewUrlValue, {
        method: "POST",
        body: formData,
        headers: {
          "X-CSRF-Token": this.getCSRFToken()
        }
      })

      const data = await response.json()

      this.hideLoading()

      if (data.success) {
        this.renderModal(data)
      } else {
        const errorMsg = data.errors ? data.errors.join(", ") : (data.error || "Preview failed")
        this.showToast(errorMsg, "error")
      }
    } catch (error) {
      this.hideLoading()
      this.showToast("Failed to preview: " + error.message, "error")
    }
  }

  renderModal(data) {
    const modalHtml = this.buildModalContent(data)
    this.modalContentTarget.innerHTML = modalHtml
    this.modalTarget.style.display = "flex"
    document.body.style.overflow = "hidden"
  }

  buildModalContent(data) {
    let html = `
      <div class="preview-modal-inner">
        <div class="preview-modal-header">
          <h3>Import Preview</h3>
          <button type="button" class="preview-modal-close" data-action="click->delver-import#closeModal">&times;</button>
        </div>
        <div class="preview-modal-body">
          <div class="preview-stats">
            <div class="preview-stat">
              <div class="preview-stat-value">${data.total_count}</div>
              <div class="preview-stat-label">Total</div>
            </div>
            <div class="preview-stat">
              <div class="preview-stat-value">${data.regular_count}</div>
              <div class="preview-stat-label">Regular</div>
            </div>
            <div class="preview-stat">
              <div class="preview-stat-value">${data.foil_count}</div>
              <div class="preview-stat-label">Foils</div>
            </div>
            <div class="preview-stat">
              <div class="preview-stat-value">${data.unique_count}</div>
              <div class="preview-stat-label">Unique</div>
            </div>
          </div>`

    // Show missing sets warning
    if (data.missing_sets && data.missing_sets.length > 0) {
      html += `
          <div class="preview-warning">
            <strong>Missing Sets (${data.missing_sets.length})</strong>
            <p>These sets will be downloaded from Scryfall during import:</p>
            <div class="preview-tags">
              ${data.missing_sets.map(s => `<span class="preview-tag preview-tag--warning">${s}</span>`).join("")}
            </div>
          </div>`
    }

    // Show found sets
    if (data.found_sets && data.found_sets.length > 0) {
      html += `
          <div class="preview-found-sets">
            <strong>Found Sets (${data.found_sets.length})</strong>
            <div class="preview-tags">
              ${data.found_sets.map(s => `<span class="preview-tag preview-tag--success">${s}</span>`).join("")}
            </div>
          </div>`
    }

    // Cards by set
    html += `<div class="preview-cards-section"><h4>Cards to Import</h4>`

    for (const [setCode, setData] of Object.entries(data.cards_by_set)) {
      const isMissing = setData.missing
      html += `
            <div class="preview-set-group">
              <div class="preview-set-header">
                <span class="preview-set-name">${setData.set_name} (${setCode})</span>
                <span class="preview-set-count">${setData.total_cards} cards</span>
                ${isMissing ? '<span class="preview-badge preview-badge--download">WILL DOWNLOAD</span>' : ''}
              </div>
              <div class="preview-cards-grid">`

      for (const card of setData.cards) {
        html += `
                <div class="preview-card">
                  <span class="preview-card-name">${this.escapeHtml(card.name)}</span>
                  <span class="preview-card-qty">x${card.quantity}${card.foil ? '<span class="preview-foil">F</span>' : ''}</span>
                </div>`
      }

      if (setData.truncated) {
        html += `<div class="preview-card preview-card--more">+${setData.total_cards - 50} more cards...</div>`
      }

      html += `
              </div>
            </div>`
    }

    html += `</div>`

    if (data.truncated) {
      html += `<div class="preview-truncated">Showing first 500 cards. Full import will include all cards.</div>`
    }

    if (data.errors && data.errors.length > 0) {
      html += `
          <div class="preview-errors">
            <strong>Warnings:</strong>
            <ul>${data.errors.map(e => `<li>${this.escapeHtml(e)}</li>`).join("")}</ul>
          </div>`
    }

    html += `
        </div>
        <div class="preview-modal-footer">
          <button type="button" class="preview-btn preview-btn--cancel" data-action="click->delver-import#closeModal">Cancel</button>
          <button type="button" class="preview-btn preview-btn--confirm" data-action="click->delver-import#confirmImport">Confirm Import</button>
        </div>
      </div>`

    return html
  }

  closeModal() {
    if (this.hasModalTarget) {
      this.modalTarget.style.display = "none"
      document.body.style.overflow = ""
    }
  }

  closeModalOnBackdrop(event) {
    // Only close if clicking directly on the backdrop (not the modal content)
    if (event.target === this.modalTarget) {
      this.closeModal()
    }
  }

  confirmImport() {
    this.closeModal()
    // Submit the actual import form
    this.formTarget.submit()
  }

  showLoading() {
    if (this.hasLoadingTarget) {
      this.loadingTarget.style.display = "flex"
    }
  }

  hideLoading() {
    if (this.hasLoadingTarget) {
      this.loadingTarget.style.display = "none"
    }
  }

  showToast(message, type = "info") {
    // Create toast element
    const toast = document.createElement("div")
    toast.className = `toast toast--${type}`
    toast.textContent = message
    toast.style.cssText = `
      position: fixed;
      bottom: 20px;
      right: 20px;
      padding: 12px 20px;
      border-radius: 6px;
      background: ${type === "error" ? "#a33" : "#333"};
      color: #fff;
      font-size: 14px;
      z-index: 10001;
      max-width: 400px;
    `
    document.body.appendChild(toast)

    setTimeout(() => {
      toast.remove()
    }, 5000)
  }

  getCSRFToken() {
    return document.querySelector('meta[name="csrf-token"]')?.content || ""
  }

  escapeHtml(text) {
    const div = document.createElement("div")
    div.textContent = text
    return div.innerHTML
  }
}
