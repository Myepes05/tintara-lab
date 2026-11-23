class ApplicationController < ActionController::API
  include ActionController::Cookies
  include JsonErrors
  include RequestProtection
  include RateLimitTiers
end
