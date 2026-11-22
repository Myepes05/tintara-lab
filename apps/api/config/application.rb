require_relative "boot"

require "rails"
# Pick the frameworks you want:
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
# require "active_storage/engine"
require "action_controller/railtie"
require "action_mailer/railtie"
# require "action_mailbox/engine"
# require "action_text/engine"
require "action_view/railtie"
# require "action_cable/engine"
# require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

# In development and test, read the repository-root .env, the single place where
# the Postgres container credentials are defined. dotenv never overwrites
# variables that are already set, so CI keeps using its own environment.
if defined?(Dotenv::Rails)
  Dotenv::Rails.files = [ File.expand_path("../../../.env", __dir__) ]
end

require_relative "../lib/api_security"

module Api
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    # api_security is required by hand above, because it is needed during boot.
    config.autoload_lib(ignore: %w[assets tasks api_security api_security.rb])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # Only loads a smaller set of middleware suitable for API only apps.
    # Middleware like session, flash, cookies can be added back manually.
    # Skip views, helpers and assets when generating a new resource.
    config.api_only = true

    # Read once, and stop the boot if a required variable is missing (D-080).
    # dotenv has already loaded the root .env by the time this line runs.
    ApiSecurity.config = ApiSecurity::Configuration.from_env(ENV)

    # API mode leaves cookies and the session out; put them back (D-079).
    config.session_store :cookie_store, **ApiSecurity::SessionCookie.options(Rails.env)
    config.middleware.use ActionDispatch::Cookies
    config.middleware.use config.session_store, config.session_options

    # Client IP (D-081): one trusted list, used by RemoteIp and by the middleware
    # that removes spoofable forwarding headers in front of it.
    config.action_dispatch.trusted_proxies = ApiSecurity::TrustedProxies
    config.middleware.insert_before ActionDispatch::RemoteIp,
                                    ApiSecurity::ClientIpSanitizer,
                                    ApiSecurity::TrustedProxies
  end
end
