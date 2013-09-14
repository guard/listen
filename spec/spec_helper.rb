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
end


# Crash loud in tests!
Thread.abort_on_exception = true
Celluloid.logger.level = Logger::ERROR

require 'rspec/retry'
RSpec.configure do |config|
  config.default_retry_count = ENV['CI'] ? 3 : 1
end
