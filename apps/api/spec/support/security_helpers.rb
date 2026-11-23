# Helpers for the API security baseline (D-078 to D-081).
module SecurityHelpers
  # RFC 5737 documentation addresses. None is in Rails' default trusted proxies,
  # unlike 127.0.0.1, which is what request specs use when nothing is set.
  UNTRUSTED_IP = "203.0.113.10"
  OTHER_UNTRUSTED_IP = "203.0.113.20"

  PUBLIC_LIMIT = 120

  def frontend_origin
    ENV.fetch("FRONTEND_ORIGIN")
  end

  def internal_token
    ENV.fetch("API_INTERNAL_TOKEN")
  end

  # Fetches a token, and with it the session cookie, then returns the headers a
  # mutating request needs:
  #
  #   post "/api/v1/things", params: { ... }, headers: csrf_headers, as: :json
  def csrf_headers
    get "/api/v1/csrf_token"

    { "X-CSRF-Token" => response.parsed_body["csrf_token"], "Origin" => frontend_origin }
  end

  def get_from(ip, path = "/api/v1/csrf_token", headers: {})
    get path, headers: headers, env: { "REMOTE_ADDR" => ip }
  end

  # Spends the whole public allowance of one client, and checks that it existed.
  def exhaust_public_limit(ip = UNTRUSTED_IP, path = "/api/v1/csrf_token", headers: {})
    PUBLIC_LIMIT.times do |index|
      get_from(ip, path, headers: headers)
      # Inside the loop, so that a broken endpoint fails at request 1, not after 120.
      expect(response.status).to eq(200), "request #{index + 1} got #{response.status}"
    end
  end

  def expect_error(status, code, message)
    expect(response).to have_http_status(status)
    expect(response.media_type).to eq("application/json")
    expect(JSON.parse(response.body)).to eq("error" => { "code" => code, "message" => message })
  end

  # Replaces the boot configuration for one example, without touching ENV.
  def use_api_security(**overrides)
    settings = {
      frontend_origin: frontend_origin,
      internal_token: internal_token,
      trusted_proxies: ""
    }.merge(overrides)

    allow(ApiSecurity).to receive(:config).and_return(ApiSecurity::Configuration.new(**settings))
  end
end

RSpec.configure do |config|
  config.include SecurityHelpers, type: :request
end
