require "ipaddr"

module ApiSecurity
  # The security settings that come from the environment (D-080).
  class Configuration
    def self.from_env(env)
      new(
        frontend_origin: required(env, "FRONTEND_ORIGIN"),
        internal_token: required(env, "API_INTERNAL_TOKEN"),
        trusted_proxies: env["TRUSTED_PROXIES"]
      )
    end

    def self.required(env, name)
      value = env[name]
      return value if value.present?

      raise ConfigurationError, "#{name} is missing or blank. Set it in the environment " \
                                "(in development, the repository-root .env; see .env.example)."
    end
    private_class_method :required

    attr_reader :frontend_origin, :internal_token, :trusted_proxies

    def initialize(frontend_origin:, internal_token:, trusted_proxies:)
      @frontend_origin = frontend_origin
      @internal_token = internal_token
      # Setting trusted proxies replaces Rails' list, so start from that list.
      @trusted_proxies = (ActionDispatch::RemoteIp::TRUSTED_PROXIES + parse_proxies(trusted_proxies)).freeze
    end

    # An empty configured token never matches, not even an empty header (D-080).
    def internal_token_matches?(candidate)
      return false if internal_token.blank? || candidate.nil?

      ActiveSupport::SecurityUtils.secure_compare(candidate, internal_token)
    end

    # The default inspect would print the token into logs and error reports.
    def inspect
      "#<#{self.class.name} frontend_origin=#{frontend_origin.inspect}>"
    end

    private
      def parse_proxies(list)
        list.to_s.split(",").map(&:strip).reject(&:empty?).map { |entry| parse_proxy(entry) }
      end

      def parse_proxy(entry)
        IPAddr.new(entry)
      rescue IPAddr::Error
        raise ConfigurationError, "TRUSTED_PROXIES contains #{entry.inspect}, which is not an IP address or CIDR."
      end
  end
end
