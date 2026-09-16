require "rails_helper"

RSpec.describe "GET /api/v1/health", type: :request do
  before { get "/api/v1/health" }

  it "responds with 200 OK" do
    expect(response).to have_http_status(:ok)
  end

  it "responds with JSON" do
    expect(response.media_type).to eq("application/json")
  end

  it "reports the status as ok" do
    expect(response.parsed_body["status"]).to eq("ok")
  end

  it "reports a parsable timestamp" do
    expect { Time.iso8601(response.parsed_body["time"]) }.not_to raise_error
  end

  it "exposes nothing but the status and the time" do
    expect(response.parsed_body.keys).to match_array(%w[status time])
  end
end
