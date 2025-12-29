import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["panel", "rows", "columns", "sortField", "sortDirection"]
  static values = { url: String }

  toggle() {
    if (this.hasPanelTarget) {
      const isHidden = this.panelTarget.style.display === "none"
      this.panelTarget.style.display = isHidden ? "block" : "none"
    }
  }

  async save() {
    const data = new FormData()
    data.append("binder_rows", this.rowsTarget.value)
    data.append("binder_columns", this.columnsTarget.value)
    data.append("binder_sort_field", this.sortFieldTarget.value)
    data.append("binder_sort_direction", this.sortDirectionTarget.value)

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
