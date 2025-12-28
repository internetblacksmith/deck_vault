// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@rails/actioncable"
import { Turbo } from "@hotwired/turbo-rails"
import * as Stimulus from "@hotwired/stimulus"

// Import and register controllers
import DarkModeController from "./controllers/dark_mode_controller.js"
import SetProgressController from "./controllers/set_progress_controller.js"
import CollectionProgressController from "./controllers/collection_progress_controller.js"

// Create Stimulus application
const application = Stimulus.Application.start()

// Register controllers
application.register("dark-mode", DarkModeController)
application.register("set-progress", SetProgressController)
application.register("collection-progress", CollectionProgressController)

window.Stimulus = Stimulus
