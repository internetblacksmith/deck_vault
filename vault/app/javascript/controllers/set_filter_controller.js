import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["search", "sort", "list", "count", "empty", "tab", "loader", "typeFilter"]
  static values = { url: String }

  connect() {
    this.currentStatus = "downloaded"
    this.currentType = ""
    this.sets = []
    
    // Only load sets if we have the URL value (index page)
    if (this.hasUrlValue && this.urlValue) {
      this.loadSets()
    }
  }

  async loadSets() {
    try {
      const response = await fetch(this.urlValue)
      if (!response.ok) throw new Error("Failed to fetch sets")
      
      this.sets = await response.json()
      this.renderSets()
      if (this.hasLoaderTarget) {
        this.loaderTarget.style.display = "none"
      }
    } catch (error) {
      console.error("Error loading sets:", error)
      if (this.hasLoaderTarget) {
        this.loaderTarget.innerHTML = '<div style="color:#a55;">Failed to load sets. Please refresh the page.</div>'
      }
    }
  }

  renderSets() {
    const html = this.sets.map(set => this.renderSetItem(set)).join("")
    this.listTarget.innerHTML = html + this.emptyTemplate()
    this.items = this.listTarget.querySelectorAll(".set-item")
    this.sort()
  }

  renderSetItem(set) {
    const totalCards = set.card_count + set.children.reduce((sum, c) => sum + c.card_count, 0)
    const hasChildren = set.children.length > 0
    const setType = set.set_type || ''
    
    return `
      <div class="set-item" 
           data-name="${set.name.toLowerCase()}" 
           data-code="${set.code.toLowerCase()}"
           data-date="${set.released_at || ''}"
           data-cards="${totalCards}"
           data-downloaded="${set.downloaded}"
           data-type="${setType}"
           ${hasChildren ? 'data-controller="collapsible"' : ''}>
        <div class="set-item-row">
          <div class="set-item-left">
            ${hasChildren ? `
              <button data-action="click->collapsible#toggle" class="collapse-btn">
                <span data-collapsible-target="icon">+</span>
              </button>
            ` : ''}
            <div class="set-item-info">
              <div class="set-item-name">${this.escapeHtml(set.name)}</div>
              <div class="set-item-meta">
                ${set.code.toUpperCase()} &middot; ${totalCards} cards
                ${setType ? `<span class="set-item-type">&middot; ${this.formatSetType(setType)}</span>` : ''}
                ${hasChildren ? `<span class="set-item-related">(+${set.children.length} related)</span>` : ''}
                ${set.released_at ? `<span class="set-item-date">${set.released_at}</span>` : ''}
              </div>
            </div>
          </div>
          <div class="set-item-actions">
            ${this.renderSetActions(set)}
          </div>
        </div>
        ${hasChildren ? this.renderChildren(set.children) : ''}
      </div>
    `
  }

  renderSetActions(set) {
    if (set.downloaded) {
      return `
        <a href="/card_sets/${set.downloaded_id}" class="action-link action-link--view">View</a>
        <button 
          type="button" 
          data-action="click->set-filter#deleteSet"
          data-set-id="${set.downloaded_id}"
          data-set-name="${this.escapeHtml(set.name)}"
          data-set-code="${set.code}"
          class="action-link action-link--delete">
          Delete
        </button>
      `
    } else {
      return `
        <form action="/card_sets/download_set" method="post">
          <input type="hidden" name="authenticity_token" value="${this.csrfToken()}">
          <input type="hidden" name="set_code" value="${set.code}">
          <button type="submit" class="download-btn">Download</button>
        </form>
      `
    }
  }

  renderChildren(children) {
    const childrenHtml = children.map(child => `
      <div class="child-item">
        <div class="child-item-info">
          <div class="child-item-name">${this.escapeHtml(child.name)}</div>
          <div class="child-item-meta">${child.code.toUpperCase()} &middot; ${child.card_count} cards</div>
        </div>
        <div class="child-item-actions">
          ${this.renderChildActions(child)}
        </div>
      </div>
    `).join("")

    return `
      <div data-collapsible-target="content" class="children-container">
        ${childrenHtml}
      </div>
    `
  }

  renderChildActions(child) {
    if (child.downloaded) {
      return `
        <a href="/card_sets/${child.downloaded_id}" class="action-link action-link--view action-link--small">View</a>
        <button 
          type="button" 
          data-action="click->set-filter#deleteSet"
          data-set-id="${child.downloaded_id}"
          data-set-name="${this.escapeHtml(child.name)}"
          data-set-code="${child.code}"
          class="action-link action-link--delete action-link--small">
          Delete
        </button>
      `
    } else {
      return `
        <form action="/card_sets/download_set" method="post">
          <input type="hidden" name="authenticity_token" value="${this.csrfToken()}">
          <input type="hidden" name="set_code" value="${child.code}">
          <button type="submit" class="download-btn download-btn--small">Download</button>
        </form>
      `
    }
  }

  emptyTemplate() {
    return '<div data-set-filter-target="empty" class="empty-state" style="display:none;">No sets found matching your search</div>'
  }

  csrfToken() {
    return document.querySelector('meta[name="csrf-token"]')?.content || ""
  }

  escapeHtml(text) {
    const div = document.createElement('div')
    div.textContent = text
    return div.innerHTML
  }

  filterByStatus(event) {
    const status = event.currentTarget.dataset.status
    this.currentStatus = status

    this.tabTargets.forEach(tab => {
      if (tab.dataset.status === status) {
        tab.style.background = "#29f"
        tab.style.color = "#fff"
      } else {
        tab.style.background = "#333"
        tab.style.color = "#888"
      }
    })

    this.filter()
  }

  filterByType(event) {
    this.currentType = event.currentTarget.value
    this.filter()
  }

  filter() {
    if (!this.items) return
    
    const query = this.searchTarget.value.toLowerCase().trim()
    let visibleCount = 0

    this.items.forEach(item => {
      const name = item.dataset.name || ""
      const code = item.dataset.code || ""
      const downloaded = item.dataset.downloaded === "true"
      const setType = item.dataset.type || ""
      
      const matchesSearch = name.includes(query) || code.includes(query)
      
      let matchesStatus = true
      if (this.currentStatus === "downloaded") {
        matchesStatus = downloaded
      } else if (this.currentStatus === "available") {
        matchesStatus = !downloaded
      }

      let matchesType = true
      if (this.currentType) {
        matchesType = setType === this.currentType
      }
      
      const visible = matchesSearch && matchesStatus && matchesType
      item.style.display = visible ? "" : "none"
      if (visible) visibleCount++
    })

    this.updateCount(visibleCount)
    
    if (this.hasEmptyTarget) {
      this.emptyTarget.style.display = visibleCount === 0 ? "" : "none"
    }
  }

  sort() {
    if (!this.items || this.items.length === 0) return
    
    const sortValue = this.sortTarget.value
    const [field, direction] = sortValue.split("-")
    
    const itemsArray = Array.from(this.items)
    
    itemsArray.sort((a, b) => {
      let aVal, bVal
      
      switch (field) {
        case "name":
          aVal = a.dataset.name || ""
          bVal = b.dataset.name || ""
          break
        case "date":
          aVal = a.dataset.date || "0000-00-00"
          bVal = b.dataset.date || "0000-00-00"
          break
        case "cards":
          aVal = parseInt(a.dataset.cards) || 0
          bVal = parseInt(b.dataset.cards) || 0
          break
        case "type":
          aVal = this.formatSetType(a.dataset.type || "")
          bVal = this.formatSetType(b.dataset.type || "")
          break
        default:
          return 0
      }
      
      let comparison = 0
      if (field === "cards") {
        comparison = aVal - bVal
      } else {
        comparison = aVal.localeCompare(bVal)
      }
      
      return direction === "desc" ? -comparison : comparison
    })
    
    // Re-append items in sorted order (before the empty message)
    const emptyEl = this.listTarget.querySelector('[data-set-filter-target="empty"]')
    itemsArray.forEach(item => {
      this.listTarget.insertBefore(item, emptyEl)
    })
    
    this.filter()
  }

  formatSetType(type) {
    const typeNames = {
      core: "Core Set",
      expansion: "Expansion",
      masters: "Masters",
      draft_innovation: "Draft Innovation",
      commander: "Commander",
      planechase: "Planechase",
      archenemy: "Archenemy",
      box: "Box Set",
      duel_deck: "Duel Deck",
      starter: "Starter Set",
      promo: "Promo",
      funny: "Funny",
      memorabilia: "Memorabilia",
      token: "Token",
      alchemy: "Alchemy",
      arsenal: "Arsenal",
      from_the_vault: "From the Vault",
      spellbook: "Spellbook",
      premium_deck: "Premium Deck",
      masterpiece: "Masterpiece",
      treasure_chest: "Treasure Chest",
      vanguard: "Vanguard",
      minigame: "Minigame"
    }
    return typeNames[type] || type
  }

  updateCount(count) {
    this.countTarget.textContent = `${count} sets`
  }

  async deleteSet(event) {
    const button = event.currentTarget
    const setId = button.dataset.setId
    const setName = button.dataset.setName
    const setCode = button.dataset.setCode

    if (!confirm(`Delete ${setName}? This will remove all cards and images.`)) {
      return
    }

    try {
      const response = await fetch(`/card_sets/${setId}`, {
        method: "DELETE",
        headers: {
          "X-CSRF-Token": this.csrfToken(),
          "Accept": "application/json"
        }
      })

      // 404 means already deleted - treat as success
      if (!response.ok && response.status !== 404) {
        throw new Error("Failed to delete set")
      }

      // Update local data
      this.updateSetAsDeleted(setCode)

      // Re-render
      this.renderSets()

      // Show toast
      const message = response.status === 404 
        ? `${setName} was already deleted` 
        : `${setName} has been deleted`
      document.dispatchEvent(new CustomEvent("toast:show", {
        detail: { message, type: "success" }
      }))

    } catch (error) {
      console.error("Error deleting set:", error)
      document.dispatchEvent(new CustomEvent("toast:show", {
        detail: { message: "Failed to delete set", type: "error" }
      }))
    }
  }

  updateSetAsDeleted(setCode) {
    this.sets = this.sets.map(set => {
      if (set.code === setCode) {
        return { ...set, downloaded: false, downloaded_id: null }
      }
      return {
        ...set,
        children: set.children.map(child => {
          if (child.code === setCode) {
            return { ...child, downloaded: false, downloaded_id: null }
          }
          return child
        })
      }
    })
  }
}
