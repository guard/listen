require 'rubygems'

require 'listen'
require 'listen/tcp'

def ci?
  ENV['CI']
end

if ci?
  require 'coveralls'
  Coveralls.wear!
end

Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each { |f| require f }

# See http://rubydoc.info/gems/rspec-core/RSpec/Core/Configuration
RSpec.configure do |config|
  config.order = :random
  config.filter_run focus: true
  config.run_all_when_everything_filtered = true
  # config.fail_fast = !ci?
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_doubled_constant_names = true
    mocks.verify_partial_doubles = true
  end
end

require 'rspec/retry'
RSpec.configure do |config|
  config.default_retry_count = ci? ? 5 : 1
end

require 'celluloid/rspec'
Thread.abort_on_exception = true
Celluloid.logger.level = Logger::ERROR

RSpec.configuration.before(:each) do
  Celluloid.boot
end

RSpec.configuration.after(:each) do
  Celluloid.shutdown
end
