# Pin npm packages by running ./bin/importmap

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin_all_from "app/javascript/controllers", under: "controllers"
# Only the sign-in page imports it from this import map (the passkeys page uses
# Madmin's), so it isn't preloaded on every page.
pin "devise/webauthn", to: "devise/webauthn.js", preload: false
