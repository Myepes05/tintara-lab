require "rails_helper"

RSpec.describe "Rate limits", type: :request do
  let(:client) { SecurityHelpers::UNTRUSTED_IP }
  let(:rate_limited) { [ :too_many_requests, "rate_limited", "Too many requests. Try again later." ] }

  describe "the public GET tier, on GET /api/v1/csrf_token" do
    it "allows 120 requests from one IP and blocks request 121" do
      exhaust_public_limit(client)
      get_from(client)

      expect_error(*rate_limited)
      expect(response.headers["Retry-After"]).to eq("60")
    end

    it "gives a new allowance when the window ends, even to a client that kept trying" do
      freeze_time
      exhaust_public_limit(client)

      travel 59.seconds
      get_from(client)
      expect_error(*rate_limited)

      travel 2.seconds
      get_from(client)
      expect(response).to have_http_status(:ok)
    end

    it "does not count one IP against another" do
      exhaust_public_limit(client)
      get_from(SecurityHelpers::OTHER_UNTRUSTED_IP)

      expect(response).to have_http_status(:ok)
    end

    # The same example twice: in either order, the second one fails if a counter leaks.
    2.times do |run|
      it "starts every example with a full allowance (run #{run + 1})" do
        exhaust_public_limit(client)
        get_from(client)

        expect_error(*rate_limited)
      end
    end

    it "exempts a valid X-Internal-Token" do
      headers = { "X-Internal-Token" => internal_token }
      exhaust_public_limit(client, headers: headers)
      get_from(client, headers: headers)

      expect(response).to have_http_status(:ok)
    end

    it "exempts a valid token even for an IP that is already blocked" do
      exhaust_public_limit(client)
      get_from(client, headers: { "X-Internal-Token" => internal_token })

      expect(response).to have_http_status(:ok)
    end

    it "treats a wrong X-Internal-Token as an ordinary request" do
      headers = { "X-Internal-Token" => "#{internal_token}x" }
      exhaust_public_limit(client, headers: headers)
      get_from(client, headers: headers)

      expect_error(*rate_limited)
    end

    it "never matches an empty configured token" do
      use_api_security(internal_token: "")
      exhaust_public_limit(client, headers: { "X-Internal-Token" => "" })
      get_from(client, headers: { "X-Internal-Token" => "" })

      expect_error(*rate_limited)
    end
  end

  describe "tiers across controllers" do
    include_context "with test endpoints"

    before do
      %w[FirstPublicTestController SecondPublicTestController].each do |name|
        define_test_controller(name) do
          limit_public_get_requests

          def handle
            render json: { handled: true }
          end
        end
      end

      define_test_controller("OtherTierTestController") do
        limit_requests scope: "other_test_tier", to: 2, within: 3.minutes

        def handle
          render json: { handled: true }
        end
      end

      draw_test_routes do
        get "/test/public/first", to: "first_public_test#handle"
        get "/test/public/second", to: "second_public_test#handle"
        post "/test/public/first", to: "first_public_test#handle"
        get "/test/other_tier", to: "other_tier_test#handle"
      end
    end

    it "shares one count between two controllers in the public tier" do
      60.times do
        get_from(client, "/test/public/first")
        expect(response).to have_http_status(:ok)
        get_from(client, "/test/public/second")
        expect(response).to have_http_status(:ok)
      end

      get_from(client, "/test/public/first")
      expect_error(*rate_limited)
      get_from(client, "/test/public/second")
      expect_error(*rate_limited)
    end

    it "shares that count with GET /api/v1/csrf_token" do
      exhaust_public_limit(client, "/test/public/first")
      get_from(client)

      expect_error(*rate_limited)
    end

    it "counts only GET and HEAD requests in the public GET tier" do
      headers = csrf_headers
      exhaust_public_limit(client)

      post "/test/public/first", headers: headers, env: { "REMOTE_ADDR" => client }

      expect(response).to have_http_status(:ok)
    end

    it "keeps separate tiers separate" do
      exhaust_public_limit(client)
      get_from(client, "/test/other_tier")

      expect(response).to have_http_status(:ok)
    end

    it "does not exempt a valid internal token from another tier" do
      headers = { "X-Internal-Token" => internal_token }
      3.times { get_from(client, "/test/other_tier", headers: headers) }

      expect_error(*rate_limited)
      expect(response.headers["Retry-After"]).to eq("180")
    end
  end

  describe "endpoints without a limit" do
    %w[/api/v1/health /up].each do |path|
      it "answers #{path} past 120 requests" do
        exhaust_public_limit(client, path)
        get_from(client, path)

        expect(response).to have_http_status(:ok)
      end
    end
  end
end
