# Pin npm packages by running ./bin/importmap

pin "application"
pin "admin_rich_text", to: "admin_rich_text.js"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin_all_from "app/javascript/controllers", under: "controllers"
pin "trix"
pin "@rails/actiontext", to: "actiontext.esm.js"
pin "lexxy", to: "lexxy.js"
pin "lexxy_setup"
pin "@rails/activestorage", to: "@rails--activestorage.js"
