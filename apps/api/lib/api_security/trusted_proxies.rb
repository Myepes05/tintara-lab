require "ipaddr"

module ApiSecurity
  # The one trusted list (D-081): Rails' defaults plus TRUSTED_PROXIES. Both
  # ClientIpSanitizer and ActionDispatch::RemoteIp read it through this object.
  module TrustedProxies
    extend Enumerable

    def self.each(&)
      ApiSecurity.config.trusted_proxies.each(&)
    end

    # True only for a single, parsable IP address inside the list.
    def self.trust?(address)
      address = address.to_s
      return false if address.include?("/") # a range is not a peer

      ip = IPAddr.new(address)
      any? { |proxy| proxy.include?(ip) }
    rescue IPAddr::Error
      false
    end
  end
end
