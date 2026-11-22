module ApiSecurity
  # The session cookie's attributes (D-079). Each is written out, even where it
  # equals a default.
  module SessionCookie
    def self.options(environment)
      {
        key: "_tintara_session",
        path: "/",
        domain: nil, # host-only: never sent to another subdomain
        httponly: true,
        same_site: :lax,
        secure: environment.to_s == "production"
      }
    end
  end
end
