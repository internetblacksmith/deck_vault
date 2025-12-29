import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["sortField", "sortDirection", "container"]
  static values = { view: String }

  connect() {
    // Container is found via target
  }

  sort() {
    if (!this.hasContainerTarget) return

    const field = this.sortFieldTarget.value
    const direction = this.sortDirectionTarget.value
    const container = this.containerTarget
    
    // Get all sortable items from the container
    const items = Array.from(container.querySelectorAll("[data-card-sort-target='item']"))
    
    if (items.length === 0) return

    items.sort((a, b) => {
      let aVal = a.dataset[`sort${this.capitalize(field)}`] || ""
      let bVal = b.dataset[`sort${this.capitalize(field)}`] || ""
      
      // Handle numeric sorting for rarity, mana (pure integers)
      if (["rarity", "mana"].includes(field)) {
        aVal = parseInt(aVal) || 0
        bVal = parseInt(bVal) || 0
        return direction === "asc" ? aVal - bVal : bVal - aVal
      }
      
      // String comparison for name, color, type, number (number is zero-padded string)
      const comparison = aVal.localeCompare(bVal)
      return direction === "asc" ? comparison : -comparison
    })

    // Re-append items in sorted order
    items.forEach(item => {
      // Items are wrapped in turbo-frames, move the frame
      const frame = item.closest("turbo-frame") || item
      container.appendChild(frame)
    })
  }

  capitalize(string) {
    return string.charAt(0).toUpperCase() + string.slice(1)
  }
}
