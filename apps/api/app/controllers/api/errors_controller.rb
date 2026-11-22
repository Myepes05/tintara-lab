module Api
  # Answers unknown paths under /api. It doesn't inherit ApplicationController:
  # there is nothing to protect, so no Origin check, token or session (D-078).
  class ErrorsController < ActionController::API
    include JsonErrors

    def not_found
      render_not_found
    end
  end
end
