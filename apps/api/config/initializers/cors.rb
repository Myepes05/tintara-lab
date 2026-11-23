# Be sure to restart your server when you modify this file.

# Cross-Origin Resource Sharing for the one frontend (D-039, D-081).
# https://github.com/cyu/rack-cors

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    # A comparison, not a string: rack-cors turns a string without a scheme into
    # a regular expression and "*" into a wildcard. This is always exact equality.
    origins { |origin, _env| origin == ApiSecurity.config.frontend_origin }

    # A pattern for the path only, because the string "/api/*" also matches /apiary.
    resource %r{\A/api(/|\z)},
      credentials: true,
      methods: %i[get post patch put delete options head],
      headers: %w[Content-Type Accept X-CSRF-Token],
      expose: %w[Retry-After]
  end
end

# Inserted second, so it ends up first, in front of Rack::Cors.
Rails.application.config.middleware.insert_before 0, ApiSecurity::XOriginRemover
