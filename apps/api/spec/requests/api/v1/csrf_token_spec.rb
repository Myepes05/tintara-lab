require "rails_helper"

RSpec.describe "GET /api/v1/csrf_token", type: :request do
  before { get "/api/v1/csrf_token" }

  it "responds with 200 OK and JSON" do
    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("application/json")
  end

  it "returns exactly one key, a non-empty csrf_token string" do
    expect(response.parsed_body.keys).to eq(%w[csrf_token])
    expect(response.parsed_body["csrf_token"]).to be_a(String).and be_present
  end

  describe "the session cookie" do
    let(:set_cookie) { Array(response.headers["Set-Cookie"]).join("\n") }

    it "is named _tintara_session" do
      expect(set_cookie).to start_with("_tintara_session=")
    end

    it "is HttpOnly and SameSite=Lax" do
      expect(set_cookie).to match(/;\s*httponly(;|$)/i).and match(/;\s*samesite=lax(;|$)/i)
    end

    it "is host-only, for the whole host" do
      expect(set_cookie).to match(/;\s*path=\/(;|$)/i)
      expect(set_cookie).not_to match(/;\s*domain=/i)
    end

    it "is not Secure outside production, so it works on http://localhost" do
      expect(set_cookie).to start_with("_tintara_session=")
      expect(set_cookie).not_to match(/;\s*secure(;|$)/i)
    end

    it "holds the CSRF secret and nothing else" do
      # session_id is the cookie store's own identifier, present in every session.
      expect(request.session.to_hash.keys).to match_array(%w[session_id _csrf_token])
    end
  end
end
