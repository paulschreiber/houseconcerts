require "active_support/core_ext/integer/time"

# An IO-like object that fans out writes to multiple targets. See the
# comment in Rails.application.configure below for why this is used
# instead of ActiveSupport::BroadcastLogger.
class MultiIO
  def initialize(*targets)
    @targets = targets
  end

  def write(...)
    @targets.each { |target| target.write(...) }
  end

  def close
    @targets.each(&:close)
  end
end

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # Code is not reloaded between requests.
  config.enable_reloading = false

  # Eager load code on boot for better performance and memory savings (ignored by Rake tasks).
  config.eager_load = true

  # Full error reports are disabled.
  config.consider_all_requests_local = false

  # Turn on fragment caching in view templates.
  config.action_controller.perform_caching = true

  # Cache assets for far-future expiry since they are all digest stamped.
  config.public_file_server.headers = { "cache-control" => "public, max-age=#{1.year.to_i}" }

  # Enable serving of images, stylesheets, and JavaScripts from an asset server.
  # config.asset_host = "http://assets.example.com"

  # Store uploaded files on the local file system (see config/storage.yml for options).
  config.active_storage.service = :local

  # Assume all access to the app is happening through a SSL-terminating reverse proxy.
  config.assume_ssl = true

  # Force all access to the app over SSL, use Strict-Transport-Security, and use secure cookies.
  config.force_ssl = true

  # Skip http-to-https redirect for the default health check endpoint.
  # config.ssl_options = { redirect: { exclude: ->(request) { request.path == "/up" } } }

  # Log to STDOUT with the current request id as a default log tag.
  config.log_tags = [ :request_id ]

  # Logs to STDOUT and log/production.log through one Logger writing to both
  # (MultiIO), not an ActiveSupport::BroadcastLogger. ActiveJob::Logging wraps
  # enqueue and perform in logger.tagged(&block), and a BroadcastLogger runs
  # that block once per target, so every job would be enqueued and performed
  # twice. A single Logger runs it once, and ActiveJob shares its log level.
  #
  # Once Rails fixes this upstream, this can be a plain
  # ActiveSupport::BroadcastLogger:
  # https://github.com/rails/rails/pull/53105
  # https://github.com/rails/rails/pull/53505
  # https://github.com/rails/rails/pull/58429
  config.logger = ActiveSupport::TaggedLogging.new(
    ActiveSupport::Logger.new(
      MultiIO.new($stdout, File.open(Rails.root.join("log/production.log"), "a")),
      formatter: Logger::Formatter.new
    )
  )

  # Change to "debug" to log everything (including potentially personally-identifiable information!)
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")

  # Prevent health checks from clogging up the logs.
  config.silence_healthcheck_path = "/up"

  # Don't log template, partial and layout renders ("Rendered layout
  # layouts/mailer.html.erb ..."), for web requests and emails alike. Each
  # request's "Completed" line still includes its total view time.
  config.action_view.logger = nil

  # Don't log any deprecations.
  config.active_support.report_deprecations = false

  # Replace the default in-process memory cache store with a durable alternative.
  config.cache_store = :solid_cache_store

  # Replace the default in-process and non-durable queuing backend for Active Job.
  config.active_job.queue_adapter = :solid_queue

  # Ignore bad email addresses and do not raise email delivery errors.
  # Set this to true and configure the email server for immediate delivery to raise delivery errors.
  # config.action_mailer.raise_delivery_errors = false

  # Specify outgoing SMTP server.
  config.action_mailer.delivery_method = :smtp
  config.action_mailer.smtp_settings = {
    user_name: Rails.application.credentials.amazon.username,
    password: Rails.application.credentials.amazon.password,
    address: Rails.application.credentials.amazon.server,
    port: 587
  }

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation cannot be found).
  config.i18n.fallbacks = true

  # Do not dump schema after migrations.
  config.active_record.dump_schema_after_migration = false

  # Only use :id for inspections in production.
  config.active_record.attributes_for_inspect = [ :id ]

  # Enable DNS rebinding protection and other `Host` header attacks: only
  # answer requests for our own domain and its subdomains (the leading dot), so
  # a spoofed Host or X-Forwarded-Host can't change the canonical, social-sharing,
  # or redirect URLs the app generates. (There's no /up health check to exclude.)
  config.hosts = [ ".#{Settings.domain}" ]

  # Set host to be used by links generated in mailer templates.
  config.action_mailer.default_url_options = { host: Settings.domain, protocol: "https" }
end
