require "rails_helper"

# The test environment can't be production, so this builds Rails' real cookie
# and session middleware from the options production would receive.
RSpec.describe "ApiSecurity::SessionCookie" do
  def set_cookie_in(environment)
    app = lambda do |env|
      ActionDispatch::Request.new(env).session[:probe] = true
      [ 200, {}, [] ]
    end
    options = ApiSecurity::SessionCookie.options(environment)
    stack = ActionDispatch::Cookies.new(ActionDispatch::Session::CookieStore.new(app, options))
    env = Rails.application.env_config.merge(Rack::MockRequest.env_for("https://api.example.test/"))

    _status, headers, _body = stack.call(env)
    Array(headers["set-cookie"]).join("\n")
  end

  it "sets a Secure, HttpOnly, SameSite=Lax, host-only cookie in production" do
    cookie = set_cookie_in("production")

    expect(cookie).to start_with("_tintara_session=")
    expect(cookie).to match(/;\s*secure(;|$)/i).and match(/;\s*httponly(;|$)/i).and match(/;\s*samesite=lax(;|$)/i)
    expect(cookie).not_to match(/;\s*domain=/i)
  end

  %w[development test].each do |environment|
    it "leaves Secure off in #{environment}" do
      expect(set_cookie_in(environment)).not_to match(/;\s*secure(;|$)/i)
    end
  end

  it "sets every attribute explicitly" do
    expect(ApiSecurity::SessionCookie.options("production")).to eq(
      key: "_tintara_session", path: "/", domain: nil, httponly: true, same_site: :lax, secure: true
    )
  end

  it "is what this application runs with" do
    expect(Rails.configuration.session_options.slice(:key, :path, :domain, :httponly, :same_site, :secure))
      .to eq(ApiSecurity::SessionCookie.options(Rails.env))
  end
end
