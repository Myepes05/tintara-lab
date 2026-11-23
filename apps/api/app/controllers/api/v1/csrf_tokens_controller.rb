module Api
  module V1
    # Hands the frontend its CSRF token in the body, because the frontend can't
    # read this host's cookies (D-039, D-079).
    class CsrfTokensController < ApplicationController
      limit_public_get_requests

      def show
        render json: { csrf_token: form_authenticity_token }
      end
    end
  end
end
