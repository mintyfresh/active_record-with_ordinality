# frozen_string_literal: true

require 'spec_helper'
ENV['RAILS_ENV'] ||= 'test'

# Translates the inline RBS signatures of files loaded from here on into runtime-checked Sorbet signatures,
# as Tapioca does when it loads the gem in an application.
require 'tapioca/internal'

require_relative 'dummy/config/environment'
abort('The Rails environment is running in production mode!') if Rails.env.production?

require 'rspec/rails'

Dir[File.expand_path('support/**/*.rb', __dir__)].each { |file| require file }

# Ensures that the test database schema matches the current schema file.
# If there are pending migrations it will invoke `db:test:prepare` to
# recreate the test database by loading the schema.
begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => error
  abort error.to_s.strip
end

RSpec.configure do |config|
  config.include FactoryBot::Syntax::Methods

  config.use_transactional_fixtures = true

  config.filter_rails_from_backtrace!
end
