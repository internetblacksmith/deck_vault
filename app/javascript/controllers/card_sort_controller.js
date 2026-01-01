import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["sortField", "sortDirection", "filterField", "searchField", "container", "setGroup"]
  static values = { view: String }

  connect() {
    // Container is found via target
  }

  sort() {
    if (!this.hasContainerTarget) return

    const field = this.sortFieldTarget.value
    const direction = this.sortDirectionTarget.value
    
    // Sort within each container (handles grouped sets)
    this.containerTargets.forEach(container => {
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
    })
  }

  filter() {
    this.applyFilters()
  }

  search() {
    this.applyFilters()
  }

  applyFilters() {
    if (!this.hasContainerTarget) return

    // Get filter value
    const filterValue = this.hasFilterFieldTarget ? this.filterFieldTarget.value : "all"
    
    // Get search query and convert wildcards to regex
    const searchQuery = this.hasSearchFieldTarget ? this.searchFieldTarget.value.toLowerCase().trim() : ""
    const searchRegex = this.buildSearchRegex(searchQuery)

    // Apply filters to all containers (handles grouped sets)
    this.containerTargets.forEach(container => {
      const items = Array.from(container.querySelectorAll("[data-card-sort-target='item']"))
      
      items.forEach(item => {
        const isOwned = item.dataset.owned === "true"
        const isFoil = item.dataset.isFoil === "true"
        const isNonfoil = item.dataset.isNonfoil === "true"
        const searchText = item.dataset.searchText || ""
        const frame = item.closest("turbo-frame") || item
        
        // Check filter condition
        let passesFilter = true
        if (filterValue === "owned") {
          passesFilter = isOwned
        } else if (filterValue === "missing") {
          passesFilter = !isOwned
        } else if (filterValue === "foil-only") {
          // Cards that can ONLY be foil (no nonfoil printing)
          passesFilter = isFoil && !isNonfoil
        } else if (filterValue === "nonfoil-only") {
          // Cards that can ONLY be nonfoil (no foil printing)
          passesFilter = isNonfoil && !isFoil
        }
        
        // Check search condition using regex for wildcard support
        let passesSearch = true
        if (searchRegex) {
          passesSearch = searchRegex.test(searchText)
        }
        
        // Show only if passes both conditions
        frame.style.display = (passesFilter && passesSearch) ? "" : "none"
      })
    })

    // Hide empty set groups when filtering/searching
    this.updateSetGroupVisibility()
  }

  // Convert search query with wildcards (* and ?) to regex
  // * matches any number of characters (including zero)
  // ? matches exactly one character
  // Without wildcards: simple substring match
  // With wildcards: pattern anchors to word boundary at start (unless starts with *)
  // Examples:
  //   "22" matches anywhere: "22", "220", "022", "card twentytwo" (substring)
  //   "22?" matches "220", "221", "229" but NOT "022" or "2200" (22 + exactly 1 char at word start)
  //   "22*" matches "22", "220", "2200" but NOT "022" (starts with 22 at word boundary)
  //   "*dragon" matches "fire dragon", "dragon" (ends with dragon)
  //   "?22" matches "022", "122" (1 char + 22 at word boundary)
  buildSearchRegex(query) {
    if (!query) return null
    
    const hasWildcard = query.includes("*") || query.includes("?")
    
    // If no wildcards, do simple substring match
    if (!hasWildcard) {
      // Escape special regex characters for literal matching
      const escaped = query.replace(/[.+^${}()|[\]\\*?]/g, "\\$&")
      try {
        return new RegExp(escaped)
      } catch (e) {
        return null
      }
    }
    
    // Escape special regex characters except * and ?
    let regexPattern = query.replace(/[.+^${}()|[\]\\]/g, "\\$&")
    
    // Convert wildcards to regex equivalents
    // * -> .* (match any characters)
    // ? -> . (match single character)
    regexPattern = regexPattern.replace(/\*/g, ".*").replace(/\?/g, ".")
    
    // Add word boundary at start if pattern doesn't start with .*
    // This makes "22?" match "220" but not "022"
    if (!query.startsWith("*")) {
      regexPattern = "(?:^|\\s)" + regexPattern
    }
    
    try {
      return new RegExp(regexPattern)
    } catch (e) {
      // If regex is invalid, fall back to simple includes
      return null
    }
  }

  // Hide set group headers when all cards in that group are hidden
  updateSetGroupVisibility() {
    if (!this.hasSetGroupTarget) return

    this.setGroupTargets.forEach(group => {
      const container = group.querySelector("[data-card-sort-target='container']")
      if (!container) return

      const items = Array.from(container.querySelectorAll("[data-card-sort-target='item']"))
      const visibleItems = items.filter(item => {
        const frame = item.closest("turbo-frame") || item
        return frame.style.display !== "none"
      })

      // Hide the entire group if no visible items
      group.style.display = visibleItems.length > 0 ? "" : "none"
    })
  }

  capitalize(string) {
    return string.charAt(0).toUpperCase() + string.slice(1)
  }
}
