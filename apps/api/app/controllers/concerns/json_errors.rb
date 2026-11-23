# The one shape of an API error (D-078):
#
#   { "error": { "code": "snake_case", "message": "An English sentence.", "details": { ... } } }
module JsonErrors
  extend ActiveSupport::Concern

  included do
    rescue_from ActionController::ParameterMissing, with: :render_bad_request
    rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
  end

  private
    def render_error(code, status:, message:, details: nil)
      error = { code: code, message: message, details: details.presence }.compact

      render json: { error: error }, status: status
    end

    def render_bad_request
      render_error "bad_request", status: :bad_request,
                                  message: "The request is invalid or missing a required parameter."
    end

    def render_not_found
      render_error "not_found", status: :not_found, message: "The requested resource was not found."
    end
end
