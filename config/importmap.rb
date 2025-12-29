# Pin npm packages by running ./bin/importmap

pin "application"
pin "@rails/actioncable", to: "@rails--actioncable.js" # @8.1.100
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"

# Pin controller files
pin_all_from "app/javascript/controllers", under: "controllers"

# Pin channel files
pin_all_from "app/javascript/channels", under: "channels"
