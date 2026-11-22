# freeze_time and travel, for specs about windows and expiry.
RSpec.configure do |config|
  config.include ActiveSupport::Testing::TimeHelpers
  config.after { travel_back }
end
