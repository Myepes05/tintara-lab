# Endpoints that exist only inside the spec suite (never in config/routes.rb).
#
# They live outside /api because routes drawn here are appended after the app's
# own, where the /api catch-all would shadow them. The protections under test
# belong to ApplicationController, so the path makes no difference to them.
module TestEndpoints
  def define_test_controller(name, &body)
    stub_const(name, Class.new(ApplicationController, &body))
  end

  def draw_test_routes(&routes)
    application = Rails.application
    application.reload_routes_unless_loaded
    application.routes.disable_clear_and_finalize = true
    application.routes.draw(&routes)
  ensure
    application.routes.disable_clear_and_finalize = false
  end
end

RSpec.shared_context "with test endpoints" do
  include TestEndpoints

  after { Rails.application.reload_routes! }
end
