// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@rails/actioncable"
import { Turbo } from "@hotwired/turbo-rails"
import * as Stimulus from "@hotwired/stimulus"

// Create Stimulus application
const application = Stimulus.Application.start()

// Configure Stimulus development experience
application.debug = false
window.Stimulus = Stimulus

// Auto-load controllers using Stimulus' built-in resolver
const controllerDefinitions = [
  ["binder", () => import("controllers/binder_controller")],
  ["binder-card", () => import("controllers/binder_card_controller")],
  ["binder-settings", () => import("controllers/binder_settings_controller")],
  ["card-sort", () => import("controllers/card_sort_controller")],
  ["card-update", () => import("controllers/card_update_controller")],
  ["collapsible", () => import("controllers/collapsible_controller")],
  ["collection-progress", () => import("controllers/collection_progress_controller")],
  ["set-filter", () => import("controllers/set_filter_controller")],
  ["set-progress", () => import("controllers/set_progress_controller")],
  ["toast-notification", () => import("controllers/toast_notification_controller")]
]

controllerDefinitions.forEach(([identifier, importFn]) => {
  importFn().then(module => {
    application.register(identifier, module.default)
  })
})
