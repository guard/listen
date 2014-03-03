require 'rubygems'
require 'listen'

def ci?; ENV['CI'] end

if ci?
  require 'coveralls'
  Coveralls.wear!
end

Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each { |f| require f }

# See http://rubydoc.info/gems/rspec-core/RSpec/Core/Configuration
RSpec.configure do |config|
  config.color_enabled = true
  config.order = :random
  config.filter_run focus: true
  config.treat_symbols_as_metadata_keys_with_true_values = true
  config.run_all_when_everything_filtered = true
  config.fail_fast = !ci?
  config.expect_with :rspec do |c|
    c.syntax = :expect
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
  Listen.stopping = false
  Celluloid.boot
end

RSpec.configuration.after(:each) do
  Celluloid.shutdown
end
