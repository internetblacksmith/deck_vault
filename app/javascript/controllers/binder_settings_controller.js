import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["panel", "rows", "columns", "sortField", "sortDirection", "includeSubsets", "search"]
  static values = { url: String }

  toggle() {
    if (this.hasPanelTarget) {
      const isHidden = this.panelTarget.style.display === "none"
      this.panelTarget.style.display = isHidden ? "block" : "none"
    }
  }

  search() {
    const query = this.searchTarget.value.toLowerCase().trim()
    const cards = document.querySelectorAll("[data-controller='binder-card']")
    
    cards.forEach(card => {
      const name = card.dataset.cardName || ""
      const number = card.dataset.cardNumber || ""
      const type = card.dataset.cardType || ""
      
      const matches = query === "" || 
                      name.includes(query) || 
                      number.includes(query) ||
                      type.includes(query)
      
      // Show/hide the card
      card.style.display = matches ? "" : "none"
    })
    
    // Also hide empty placeholder slots when searching
    const placeholders = document.querySelectorAll("[data-binder-target='spread'] > div > div[style*='dashed']")
    placeholders.forEach(placeholder => {
      placeholder.style.display = query === "" ? "" : "none"
    })
  }

  async save() {
    const data = new FormData()
    data.append("binder_rows", this.rowsTarget.value)
    data.append("binder_columns", this.columnsTarget.value)
    data.append("binder_sort_field", this.sortFieldTarget.value)
    data.append("binder_sort_direction", this.sortDirectionTarget.value)
    
    // Include subsets toggle (only if present)
    if (this.hasIncludeSubsetsTarget) {
      data.append("include_subsets", this.includeSubsetsTarget.checked)
    }

    try {
      const response = await fetch(this.urlValue, {
        method: "PATCH",
        headers: {
          "X-CSRF-Token": this.csrfToken(),
          "Accept": "application/json"
        },
        body: data
      })

      if (response.ok) {
        // Reload page to apply new binder settings
        window.location.reload()
      } else {
        console.error("Failed to save binder settings")
      }
    } catch (error) {
      console.error("Error saving binder settings:", error)
    }
  }

  csrfToken() {
    return document.querySelector('meta[name="csrf-token"]')?.content || ""
  }
}
