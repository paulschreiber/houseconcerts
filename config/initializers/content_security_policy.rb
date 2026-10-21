# Be sure to restart your server when you modify this file.

# Application-wide content security policy. It's a safety net: if an escaping
# mistake ever lets markup into a page (e.g. the admin pages that show
# visitor-submitted names), injected scripts still won't run.
# See https://guides.rubyonrails.org/security.html#content-security-policy-header

GOOGLE_ANALYTICS_SCRIPT_HOST = "https://*.googletagmanager.com".freeze
GOOGLE_ANALYTICS_HOSTS = [ "https://*.google-analytics.com", "https://*.analytics.google.com", GOOGLE_ANALYTICS_SCRIPT_HOST ].freeze

# Madmin's layout adds `<script type="module">import "trix"</script>` without a
# nonce, so allow that exact script by its hash.
MADMIN_TRIX_IMPORT_HASH = "'sha256-V5zew2x5YyErASs5rh5r3bTP+k/2KxYM6dnIXeUHtVw='".freeze

Rails.application.configure do
  config.content_security_policy do |policy|
    # Google Analytics' hosts are only allowed when it's set up.
    analytics = Settings.google_analytics_id.present?

    policy.default_src     :self
    policy.base_uri        :self
    policy.form_action     :self
    policy.frame_ancestors :none
    policy.object_src      :none
    policy.font_src        :self, :data
    policy.img_src         :self, :data, *(GOOGLE_ANALYTICS_HOSTS if analytics)
    policy.connect_src     :self, *(GOOGLE_ANALYTICS_HOSTS if analytics)
    # Importmap tags and the inline Google Analytics snippet get a nonce.
    policy.script_src      :self, *(GOOGLE_ANALYTICS_SCRIPT_HOST if analytics), MADMIN_TRIX_IMPORT_HASH
    # Turbo's progress bar and Trix inject <style> elements. Inline styles
    # can't run script, so they're allowed rather than nonced.
    policy.style_src       :self, :unsafe_inline
  end

  # Nonces for importmap tags and inline scripts. They're per session, not per
  # request, because Turbo Drive keeps the first page's CSP header across
  # visits. The nonce is stored in the (encrypted) session rather than derived
  # from the session id, which is still blank on a visitor's first request.
  config.content_security_policy_nonce_generator = ->(request) { request.session[:csp_nonce] ||= SecureRandom.base64(16) }
  config.content_security_policy_nonce_directives = %w[script-src]
end
