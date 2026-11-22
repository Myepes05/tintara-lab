module ApiSecurity
  # Runs before ActionDispatch::RemoteIp, which believes forwarding headers from
  # any peer (D-081). After this, the only one left is an X-Forwarded-For that
  # a trusted peer sent, so request.remote_ip is safe as a rate-limit key.
  class ClientIpSanitizer
    def initialize(app, trusted_proxies)
      @app = app
      @trusted_proxies = trusted_proxies
    end

    def call(env)
      env.delete("HTTP_CLIENT_IP")
      env.delete("HTTP_FORWARDED")
      env.delete("HTTP_X_FORWARDED_FOR") unless @trusted_proxies.trust?(env["REMOTE_ADDR"])

      @app.call(env)
    end
  end
end
