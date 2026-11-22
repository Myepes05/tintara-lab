# CSRF protection for an API called from another origin (D-039, D-079).
module RequestProtection
  extend ActiveSupport::Concern

  include ActionController::RequestForgeryProtection

  included do
    # config.action_controller reaches ActionController::Base, but these two
    # settings are silently skipped for ActionController::API, so set them here.
    self.allow_forgery_protection = true
    # Rails' check compares Origin with the API's own host, which a frontend on
    # another origin never matches. verify_request_origin replaces it.
    self.forgery_protection_origin_check = false

    # The order matters: the Origin is checked before the token.
    before_action :verify_request_origin
    protect_from_forgery with: :exception

    rescue_from ActionController::InvalidAuthenticityToken, with: :render_invalid_csrf_token
  end

  private
    def verify_request_origin
      return if request.get? || request.head? || request.options?

      render_invalid_origin unless request.origin == ApiSecurity.config.frontend_origin
    end

    # Rails also accepts an authenticity_token parameter; this API takes only the header.
    def request_authenticity_tokens
      [ request.x_csrf_token ]
    end

    def render_invalid_origin
      render_error "invalid_origin", status: :forbidden, message: "The request origin is not allowed."
    end

    def render_invalid_csrf_token
      render_error "invalid_csrf_token", status: :forbidden, message: "The CSRF token is missing or invalid."
    end
end
