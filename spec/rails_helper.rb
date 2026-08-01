require "spec_helper"
ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"

abort("The Rails environment is running in production mode!") if Rails.env.production?

# `.rspec` does `--require rails_helper`, which means Rails generators also load
# this file — under RAILS_ENV=development, where test-only gems are absent.
# Bail out early there so `rails generate` doesn't crash.
return unless Rails.env.test?

require "rspec/rails"

# Load everything under spec/support (matchers, helpers, shared examples).
Rails.root.glob("spec/support/**/*.rb").sort_by(&:to_s).each { |f| require f }

begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  abort e.to_s.strip
end

RSpec.configure do |config|
  config.fixture_paths = [ Rails.root.join("spec/fixtures") ]
  config.use_transactional_fixtures = true

  # Derive `type: :model`, `type: :request`, etc. from the spec's directory.
  config.infer_spec_type_from_file_location!

  config.filter_rails_from_backtrace!
end
