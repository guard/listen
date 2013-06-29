require 'rubygems'
require 'coveralls'
Coveralls.wear!

require 'listen'

Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each { |f| require f }

# See http://rubydoc.info/gems/rspec-core/RSpec/Core/Configuration
RSpec.configure do |config|
  config.color_enabled = true
  config.order = :random
  config.filter_run focus: true
  config.treat_symbols_as_metadata_keys_with_true_values = true
  config.run_all_when_everything_filtered = true
  # config.filter_run_excluding broken: true
  config.fail_fast = true
end

# Crash loud in tests!
Thread.abort_on_exception = true

require 'rspec/retry'
ENV['RSPEC_RETRY'] ||= ENV['TRAVIS'] ? '3' : '1'
