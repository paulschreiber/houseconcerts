# Be sure to restart your server when you modify this file.

# Application-wide content security policy. It's a safety net: if an escaping
# mistake ever lets markup into a page (e.g. the admin pages that show
# visitor-submitted names), injected scripts still won't run.
# See https://guides.rubyonrails.org/security.html#content-security-policy-header

GOOGLE_ANALYTICS_HOSTS = %w[
  https://*.google-analytics.com
  https://*.analytics.google.com
  https://*.googletagmanager.com
].freeze

# Madmin's layout adds `<script type="module">import "trix"</script>` without a
# nonce, so allow that exact script by its hash.
MADMIN_TRIX_IMPORT_HASH = "'sha256-V5zew2x5YyErASs5rh5r3bTP+k/2KxYM6dnIXeUHtVw='".freeze

Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src     :self
    policy.base_uri        :self
    policy.form_action     :self
    policy.frame_ancestors :none
    policy.object_src      :none
    policy.font_src        :self, :data
    policy.img_src         :self, :data, *GOOGLE_ANALYTICS_HOSTS
    policy.connect_src     :self, *GOOGLE_ANALYTICS_HOSTS
    # Importmap tags and the inline Google Analytics snippet get a nonce.
    # Madmin loads tom-select and tailwindcss-stimulus-components from jspm.
    policy.script_src      :self, "https://*.googletagmanager.com", "https://ga.jspm.io", MADMIN_TRIX_IMPORT_HASH
    # Turbo's progress bar and Trix inject <style> elements, and Madmin loads
    # flatpickr and tom-select CSS from unpkg. Inline styles can't run script,
    # so they're allowed rather than nonced.
    policy.style_src       :self, :unsafe_inline, "https://unpkg.com"
  end

  # Nonces for importmap tags and inline scripts. They're per session, not per
  # request, because Turbo Drive keeps the first page's CSP header across
  # visits. The nonce is stored in the (encrypted) session rather than derived
  # from the session id, which is still blank on a visitor's first request.
  config.content_security_policy_nonce_generator = ->(request) { request.session[:csp_nonce] ||= SecureRandom.base64(16) }
  config.content_security_policy_nonce_directives = %w[script-src]
end
