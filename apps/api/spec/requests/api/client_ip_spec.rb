require "rails_helper"

# REMOTE_ADDR is always explicit here: the request-spec default, 127.0.0.1, is a
# trusted proxy and would hide the spoofing these examples exist to catch.
RSpec.describe "Client IP and trusted proxies", type: :request do
  include_context "with test endpoints"

  before do
    define_test_controller("ClientIpTestController") do
      def show
        render json: { ip: request.remote_ip }
      end
    end

    draw_test_routes { get "/test/client_ip", to: "client_ip_test#show" }
  end

  let(:peer) { SecurityHelpers::UNTRUSTED_IP }
  let(:visitor) { "198.51.100.7" }

  def resolved_ip(remote_addr, headers = {})
    get_from(remote_addr, "/test/client_ip", headers: headers)
    expect(response).to have_http_status(:ok)
    response.parsed_body["ip"]
  end

  describe "from an untrusted peer" do
    forgeries = {
      "X-Forwarded-For" => ->(ip) { ip },
      "Client-IP" => ->(ip) { ip },
      "Forwarded" => ->(ip) { "for=#{ip}" }
    }

    forgeries.each do |header, value|
      it "ignores #{header}" do
        expect(resolved_ip(peer, header => value.call(visitor))).to eq(peer)
      end

      it "keeps a blocked client blocked while it rotates #{header}" do
        exhaust_public_limit(peer)

        1.upto(10) do |host|
          get_from(peer, headers: { header => value.call("198.51.100.#{host}") })

          expect(response).to have_http_status(:too_many_requests)
        end
      end

      it "counts requests with a rotating #{header} as one client" do
        SecurityHelpers::PUBLIC_LIMIT.times do |host|
          get_from(peer, headers: { header => value.call("198.51.100.#{host}") })
          expect(response).to have_http_status(:ok)
        end
        get_from(peer)

        expect(response).to have_http_status(:too_many_requests)
      end
    end

    it "ignores all three headers sent together" do
      headers = { "X-Forwarded-For" => visitor, "Client-IP" => "198.51.100.8", "Forwarded" => "for=198.51.100.9" }

      expect(resolved_ip(peer, headers)).to eq(peer)
    end
  end

  describe "a blank or unparsable peer" do
    [ "", "not-an-ip", "10.0.0.0/8", "127.0.0.1, 203.0.113.10" ].each do |remote_addr|
      it "treats #{remote_addr.inspect} as untrusted" do
        expect(resolved_ip(remote_addr, "X-Forwarded-For" => visitor)).not_to eq(visitor)
      end
    end
  end

  shared_examples "a trusted peer" do
    it "lets X-Forwarded-For set the client IP" do
      expect(resolved_ip(proxy, "X-Forwarded-For" => visitor)).to eq(visitor)
    end

    it "lets X-Forwarded-For set the rate-limit key" do
      exhaust_public_limit(proxy, headers: { "X-Forwarded-For" => visitor })

      get_from(proxy, headers: { "X-Forwarded-For" => "198.51.100.8" })
      expect(response).to have_http_status(:ok)

      get_from(visitor)
      expect(response).to have_http_status(:too_many_requests)
    end

    it "ignores a forged leftmost entry when the proxy appended the real address" do
      expect(resolved_ip(proxy, "X-Forwarded-For" => "198.51.100.99, #{visitor}")).to eq(visitor)
    end

    it "skips a trusted proxy at the end of the list" do
      expect(resolved_ip(proxy, "X-Forwarded-For" => "#{visitor}, #{proxy}")).to eq(visitor)
    end

    it "does not let Client-IP override X-Forwarded-For" do
      expect(resolved_ip(proxy, "X-Forwarded-For" => visitor, "Client-IP" => "198.51.100.8")).to eq(visitor)
    end

    it "does not let Forwarded override X-Forwarded-For" do
      expect(resolved_ip(proxy, "X-Forwarded-For" => visitor, "Forwarded" => "for=198.51.100.8")).to eq(visitor)
    end

    it "ignores Client-IP and Forwarded on their own" do
      expect(resolved_ip(proxy, "Client-IP" => visitor)).to eq(proxy)
      expect(resolved_ip(proxy, "Forwarded" => "for=#{visitor}")).to eq(proxy)
    end
  end

  describe "from a peer in Rails' defaults" do
    let(:proxy) { "10.1.2.3" }

    it_behaves_like "a trusted peer"
  end

  describe "from a peer listed in TRUSTED_PROXIES" do
    let(:proxy) { "192.0.2.44" }

    before { use_api_security(trusted_proxies: "192.0.2.0/24") }

    it_behaves_like "a trusted peer"

    it "still trusts Rails' defaults" do
      expect(resolved_ip("127.0.0.1", "X-Forwarded-For" => visitor)).to eq(visitor)
    end
  end

  describe "conflicting Client-IP and X-Forwarded-For" do
    { "untrusted" => "203.0.113.10", "trusted" => "10.1.2.3" }.each do |kind, remote_addr|
      it "never raise IpSpoofAttackError from an #{kind} peer" do
        headers = { "Client-IP" => "198.51.100.8", "X-Forwarded-For" => "198.51.100.7" }

        expect { get_from(remote_addr, "/test/client_ip", headers: headers) }.not_to raise_error
        expect(response).to have_http_status(:ok)
      end
    end
  end

  it "sanitizes immediately before RemoteIp, which uses the same trusted list" do
    stack = Rails.application.middleware.map(&:name)

    expect(stack[stack.index("ActionDispatch::RemoteIp") - 1]).to eq("ApiSecurity::ClientIpSanitizer")
    expect(Rails.configuration.action_dispatch.trusted_proxies).to equal(ApiSecurity::TrustedProxies)
  end
end
