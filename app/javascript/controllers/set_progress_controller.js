import { Controller } from "@hotwired/stimulus"
import { subscribeToSetProgress } from "../channels/set_progress"

export default class extends Controller {
  static values = {
    setId: Number,
    isDownloading: Boolean
  }

  connect() {
    if (this.isDownloadingValue) {
      this.subscribeToProgress()
    }
  }

  subscribeToProgress() {
    const progressBar = this.element.querySelector("#progress-bar")
    
    if (progressBar) {
      subscribeToSetProgress(this.setIdValue, (data) => {
        console.log("Progress update received:", data)
        
        if (data.percentage) {
          progressBar.style.width = data.percentage + "%"
        }
        
        if (data.type === "completed") {
          location.reload()
        }
      })
    }
  }
}
