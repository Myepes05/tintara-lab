# Rate limits per IP (D-029, D-080, D-081), on top of Rails' rate_limit. A task
# adds a limit with one declaration in its controller:
#
#   limit_requests scope: "login", to: 5, within: 3.minutes, only: :create
#
# The scope names the tier: controllers that use the same one share one count.
module RateLimitTiers
  extend ActiveSupport::Concern

  class_methods do
    def limit_requests(scope:, to:, within:, **options)
      rate_limit to: to, within: within, scope: scope, store: Rails.cache,
                 by: -> { request.remote_ip },
                 with: -> { render_rate_limited(retry_after: within) },
                 **options
    end

    # The exemption is written inline, not as a method, so that no other tier
    # can pick it up by accident (D-045).
    def limit_public_get_requests
      limit_requests scope: "public_get", to: 120, within: 1.minute,
                     if: -> { request.get? || request.head? },
                     unless: -> { ApiSecurity.config.internal_token_matches?(request.headers["X-Internal-Token"]) }
    end
  end

  private
    def render_rate_limited(retry_after:)
      response.set_header("Retry-After", retry_after.to_i.to_s)
      render_error "rate_limited", status: :too_many_requests, message: "Too many requests. Try again later."
    end
end
