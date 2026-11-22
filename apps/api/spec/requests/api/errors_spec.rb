require "rails_helper"

RSpec.describe "JSON errors", type: :request do
  include_context "with test endpoints"

  let(:not_found) { [ :not_found, "not_found", "The requested resource was not found." ] }

  describe "an unknown path under /api" do
    %i[get post put patch delete options].each do |verb|
      it "is 404 not_found for #{verb.to_s.upcase}, with no token and no Origin" do
        public_send(verb, "/api/v1/does-not-exist")

        expect_error(*not_found)
      end
    end

    it "is 404 for HEAD" do
      head "/api/v1/does-not-exist"

      expect(response).to have_http_status(:not_found)
    end

    it "is 404 whatever the depth or the extension" do
      %w[/api /api/ /api/nope /api/v1/a/b/c /api/v1/nope.json /api/v2/health].each do |path|
        get path

        expect_error(*not_found)
      end
    end

    it "is 404 for an existing path called with a method it doesn't have" do
      post "/api/v1/health"

      expect_error(*not_found)
    end

    it "is 404 before any token, Origin or body is looked at" do
      post "/api/v1/does-not-exist", params: "{not json",
                                     headers: { "Origin" => "https://evil.example", "Content-Type" => "application/json" }

      expect_error(*not_found)
    end

    it "does not create a session" do
      post "/api/v1/does-not-exist"

      expect_error(*not_found)
      expect(response.headers["Set-Cookie"]).to be_blank
    end

    it "does not swallow /up or the health endpoint" do
      %w[/up /api/v1/health].each do |path|
        get path

        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe "errors raised by a controller" do
    before do
      define_test_controller("ErrorsTestController") do
        def missing_parameter
          params.require(:name)
        end

        def missing_record
          raise ActiveRecord::RecordNotFound, "Couldn't find SecretThing with id=1"
        end

        def with_details
          render_error "example_code", status: :unprocessable_content, message: "An example.",
                                       details: { name: [ "can't be blank" ] }
        end

        def with_empty_details
          render_error "example_code", status: :unprocessable_content, message: "An example.", details: {}
        end
      end

      draw_test_routes do
        %w[missing_parameter missing_record with_details with_empty_details].each do |action|
          get "/test/errors/#{action}", to: "errors_test##{action}"
        end
      end
    end

    it "renders a missing required parameter as 400 bad_request" do
      get "/test/errors/missing_parameter"

      expect_error(:bad_request, "bad_request", "The request is invalid or missing a required parameter.")
    end

    it "renders a missing record as 404 not_found, without naming the model" do
      get "/test/errors/missing_record"

      expect_error(*not_found)
    end

    it "renders details when there are some" do
      get "/test/errors/with_details"

      expect(response).to have_http_status(:unprocessable_content)
      expect(JSON.parse(response.body)).to eq(
        "error" => { "code" => "example_code", "message" => "An example.", "details" => { "name" => [ "can't be blank" ] } }
      )
    end

    it "omits details when they are empty" do
      get "/test/errors/with_empty_details"

      expect_error(:unprocessable_content, "example_code", "An example.")
    end
  end
end
