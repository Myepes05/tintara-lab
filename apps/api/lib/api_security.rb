# The API security baseline that has to exist at boot (D-078 to D-081).
#
# config/application.rb requires this file by hand and Zeitwerk ignores it:
# middleware and boot configuration must never be reloaded.
module ApiSecurity
  class ConfigurationError < StandardError; end

  class << self
    # Set once at boot, in config/application.rb. Everything else reads it from
    # here, so a spec can replace it in one place.
    attr_accessor :config
  end
end

require_relative "api_security/configuration"
require_relative "api_security/session_cookie"
require_relative "api_security/trusted_proxies"
require_relative "api_security/client_ip_sanitizer"
require_relative "api_security/x_origin_remover"
