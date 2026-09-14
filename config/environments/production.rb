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

  # ActiveJob::Base.logger defaults to Rails.logger. ActiveJob::Logging
  # wraps both #enqueue and #perform_now in logger.tagged(&block) -- a
  # block that does real work, not just a log line. A BroadcastLogger's
  # #method_missing maps a multi-target call across every broadcast,
  # running the wrapped block once per target. With two targets, every job
  # enqueue and perform ran twice, including the underlying
  # solid_queue_jobs insert (see 75b2925). A single Logger's #tagged only
  # ever runs the block once, so fanning out at the IO layer instead of
  # the Logger layer avoids the problem entirely -- and as a bonus, there's
  # only one Logger instance and one log level to keep in sync, instead of
  # a second, separately-configured logger for ActiveJob that this file
  # used to set up by hand.
  #
  # Once Rails fixes this upstream, we can go back to a plain
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

  # Enable DNS rebinding protection and other `Host` header attacks.
  # config.hosts = [
  #   "example.com",     # Allow requests from example.com
  #   /.*\.example\.com/ # Allow requests from subdomains like `www.example.com`
  # ]
  #
  # Skip DNS rebinding protection for the default health check endpoint.
  # config.host_authorization = { exclude: ->(request) { request.path == "/up" } }

  # Set host to be used by links generated in mailer templates.
  config.action_mailer.default_url_options = { host: Settings.domain, protocol: "https" }
end
