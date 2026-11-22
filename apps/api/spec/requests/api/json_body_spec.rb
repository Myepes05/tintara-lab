require "rails_helper"

# Rails 8.1.3.1 with json 3.0 raises inside ActiveSupport::JSON.decode, which
# breaks both of these. It is the reason the Gemfile holds json below 3.
RSpec.describe "JSON decoding", type: :request do
  include_context "with test endpoints"

  before do
    stub_const("JsonBodyTestController", Class.new(ActionController::API) do
      def echo
        render json: { name: params[:name] }
      end
    end)

    draw_test_routes { post "/test/json_body", to: "json_body_test#echo" }
  end

  it "parses a JSON request body" do
    post "/test/json_body", params: { name: "Example" }, as: :json

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body["name"]).to eq("Example")
  end

  it "reads back an encrypted cookie, which is how the session is stored" do
    jar = ActionDispatch::Request.new(Rails.application.env_config.merge(Rack::MockRequest.env_for("/"))).cookie_jar
    jar.encrypted[:example] = { "stored" => true }

    expect(jar.encrypted[:example]).to eq("stored" => true)
  end
end
