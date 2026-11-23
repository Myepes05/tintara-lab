require "rails_helper"

RSpec.describe "CORS", type: :request do
  def preflight(path = "/api/v1/csrf_token", origin: frontend_origin, method: "POST", headers: "x-csrf-token")
    options path, headers: {
      "Origin" => origin,
      "Access-Control-Request-Method" => method,
      "Access-Control-Request-Headers" => headers
    }
  end

  describe "a preflight from the frontend origin" do
    it "allows that exact origin, with credentials" do
      preflight

      expect(response).to have_http_status(:ok)
      expect(response.headers["Access-Control-Allow-Origin"]).to eq(frontend_origin)
      expect(response.headers["Access-Control-Allow-Credentials"]).to eq("true")
    end

    it "allows the X-CSRF-Token header" do
      preflight

      expect(response.headers["Access-Control-Allow-Headers"].to_s.downcase).to include("x-csrf-token")
    end

    it "allows Content-Type and Accept beside the token" do
      preflight(headers: "content-type, accept, x-csrf-token")

      expect(response.headers["Access-Control-Allow-Origin"]).to eq(frontend_origin)
    end

    %w[GET POST PATCH PUT DELETE OPTIONS HEAD].each do |verb|
      it "allows #{verb}" do
        preflight(method: verb)

        expect(response.headers["Access-Control-Allow-Origin"]).to eq(frontend_origin)
        expect(response.headers["Access-Control-Allow-Methods"].to_s.split(", ")).to include(verb)
      end
    end

    it "is answered for a path that the catch-all would otherwise handle" do
      preflight("/api/v1/does-not-exist")

      expect(response).to have_http_status(:ok)
      expect(response.headers["Access-Control-Allow-Origin"]).to eq(frontend_origin)
    end

    it "does not allow other headers, such as the server-only X-Internal-Token" do
      preflight(headers: "x-internal-token")

      expect(response.headers["Access-Control-Allow-Origin"]).to be_nil
    end
  end

  describe "a preflight from any other origin" do
    it "gets no Access-Control-Allow-Origin, however similar the origin looks" do
      others = [ "https://evil.example", "null", "#{frontend_origin}/", "#{frontend_origin}.evil.example",
                 "#{frontend_origin}0", frontend_origin.upcase ]

      others.each do |origin|
        preflight(origin: origin)

        expect(response.headers["Access-Control-Allow-Origin"]).to be_nil, "allowed #{origin.inspect}"
      end
    end
  end

  it "follows the configured origin, without a second allowed one" do
    use_api_security(frontend_origin: "https://www.example.test")

    preflight(origin: "https://www.example.test")
    expect(response.headers["Access-Control-Allow-Origin"]).to eq("https://www.example.test")

    preflight(origin: frontend_origin)
    expect(response.headers["Access-Control-Allow-Origin"]).to be_nil
  end

  it "does not apply outside /api" do
    %w[/up /apiary].each do |path|
      preflight(path, method: "GET")

      expect(response.headers["Access-Control-Allow-Origin"]).to be_nil
    end
  end

  describe "an actual response to the frontend origin" do
    it "allows credentials and exposes Retry-After" do
      get "/api/v1/csrf_token", headers: { "Origin" => frontend_origin }

      expect(response.headers["Access-Control-Allow-Origin"]).to eq(frontend_origin)
      expect(response.headers["Access-Control-Allow-Credentials"]).to eq("true")
      expect(response.headers["Access-Control-Expose-Headers"]).to eq("Retry-After")
    end

    it "exposes Retry-After on a 429 too" do
      exhaust_public_limit
      get_from(SecurityHelpers::UNTRUSTED_IP, headers: { "Origin" => frontend_origin })

      expect(response).to have_http_status(:too_many_requests)
      expect(response.headers["Access-Control-Allow-Origin"]).to eq(frontend_origin)
      expect(response.headers["Access-Control-Expose-Headers"]).to eq("Retry-After")
    end

    it "lets the frontend read an error" do
      get "/api/v1/does-not-exist", headers: { "Origin" => frontend_origin }

      expect(response.headers["Access-Control-Allow-Origin"]).to eq(frontend_origin)
      expect_error(:not_found, "not_found", "The requested resource was not found.")
    end
  end
end
