import { Controller } from "@hotwired/stimulus"
import { subscribeToSetProgress } from "channels/set_progress"

export default class extends Controller {
  connect() {
    this.subscribeToAllSets()
  }

  subscribeToAllSets() {
    const downloadingBars = this.element.querySelectorAll("[data-set-id]")
    
    downloadingBars.forEach((bar) => {
      const setId = bar.getAttribute("data-set-id")
      if (setId) {
        subscribeToSetProgress(setId, (data) => {
          const progressBar = bar
          const container = bar.closest(".group")
          
          // Update progress bar
          if (data.percentage) {
            progressBar.style.width = data.percentage + "%"
          }
          
          // Update text
          const statusText = container.querySelector("span.animate-pulse")
          if (statusText) {
            if (data.type === "completed") {
              const title = container.querySelector("h3")?.textContent || "Set"
              container.innerHTML = `
                <div class="flex justify-between items-start mb-2">
                  <div class="flex-1">
                    <h3 class="font-bold text-white">${title}</h3>
                    <div class="text-xs text-purple-300 mt-1">
                      <p>${data.images_downloaded} / ${data.card_count} cards</p>
                    </div>
                  </div>
                </div>
                <div class="mt-3 inline-flex items-center px-3 py-1 rounded-full text-xs font-semibold bg-green-500/20 text-green-300">
                  ✓ All images ready
                </div>
              `
            } else {
              const percentText = container.querySelector(
                "span.text-purple-300:last-of-type"
              )
              if (percentText) {
                percentText.textContent =
                  data.images_downloaded + "/" + data.card_count
              }
            }
          }
        })
      }
    })
  }
}
