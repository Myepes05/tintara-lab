module Api
  module V1
    # Confirms that the API boots and can answer a request. It deliberately
    # returns nothing beyond the status and the current time.
    class HealthController < ApplicationController
      def show
        render json: { status: "ok", time: Time.current.utc.iso8601 }
      end
    end
  end
end
