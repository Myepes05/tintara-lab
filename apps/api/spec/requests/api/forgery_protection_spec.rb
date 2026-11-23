require "rails_helper"

RSpec.describe "Forgery protection and the Origin check", type: :request do
  include_context "with test endpoints"

  before do
    define_test_controller("ProtectedTestController") do
      def handle
        render json: { handled: true }
      end
    end

    draw_test_routes do
      match "/test/protected", to: "protected_test#handle", via: %i[get post put patch delete]
    end
  end

  let(:invalid_origin) { [ :forbidden, "invalid_origin", "The request origin is not allowed." ] }
  let(:invalid_token) { [ :forbidden, "invalid_csrf_token", "The CSRF token is missing or invalid." ] }

  %i[post put patch delete].each do |verb|
    describe verb.to_s.upcase do
      it "succeeds with a valid token and the frontend Origin" do
        public_send(verb, "/test/protected", headers: csrf_headers)

        expect(response).to have_http_status(:ok)
      end

      it "rejects a missing token" do
        public_send(verb, "/test/protected", headers: csrf_headers.except("X-CSRF-Token"))

        expect_error(*invalid_token)
      end

      it "rejects a missing Origin, even with a valid token" do
        public_send(verb, "/test/protected", headers: csrf_headers.except("Origin"))

        expect_error(*invalid_origin)
      end
    end
  end

  it "accepts a JSON request" do
    post "/test/protected", params: { name: "Example" }, headers: csrf_headers, as: :json

    expect(response).to have_http_status(:ok)
  end

  it "rejects a wrong token" do
    post "/test/protected", headers: csrf_headers.merge("X-CSRF-Token" => "wrong")

    expect_error(*invalid_token)
  end

  it "rejects a token that belongs to another session" do
    headers = csrf_headers
    reset!

    post "/test/protected", headers: headers

    expect_error(*invalid_token)
  end

  it "does not read the token from the parameters, only from X-CSRF-Token" do
    headers = csrf_headers

    post "/test/protected", params: { authenticity_token: headers["X-CSRF-Token"] },
                            headers: headers.slice("Origin")

    expect_error(*invalid_token)
  end

  it "rejects any Origin that is not exactly the frontend's, even with a valid token" do
    headers = csrf_headers
    # The API's own origin is in the list: it is what Rails' built-in check would accept.
    others = [ "https://evil.example", "null", "", "#{frontend_origin}/", frontend_origin.upcase,
               "http://www.example.com" ]

    others.each do |origin|
      post "/test/protected", headers: headers.merge("Origin" => origin)

      expect_error(*invalid_origin)
    end
  end

  # rack-cors copies X-Origin into a missing Origin before the app sees the request.
  it "does not accept X-Origin in place of a missing Origin" do
    post "/test/protected", headers: csrf_headers.except("Origin").merge("X-Origin" => frontend_origin)

    expect_error(*invalid_origin)
  end

  it "checks the Origin before the token" do
    post "/test/protected", headers: { "Origin" => "https://evil.example" }

    expect_error(*invalid_origin)
  end

  it "does not block a GET with no token and no Origin" do
    get "/test/protected"

    expect(response).to have_http_status(:ok)
  end

  it "does not block a HEAD with no token and no Origin" do
    head "/test/protected"

    expect(response).to have_http_status(:ok)
  end

  it "does not apply the Origin check to OPTIONS" do
    draw_test_routes { match "/test/options", to: "protected_test#handle", via: :options }

    # Rails itself still asks OPTIONS for a token, so send one and only leave out the Origin.
    options "/test/options", headers: csrf_headers.except("Origin")

    expect(response).to have_http_status(:ok)
  end
end
