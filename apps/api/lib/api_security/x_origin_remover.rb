module ApiSecurity
  # rack-cors 3.0.0 copies X-Origin into Origin when Origin is missing, which
  # would let a request without Origin pass the Origin check (D-079). The header
  # has to be gone before Rack::Cors runs.
  class XOriginRemover
    def initialize(app)
      @app = app
    end

    def call(env)
      env.delete("HTTP_X_ORIGIN")

      @app.call(env)
    end
  end
end
