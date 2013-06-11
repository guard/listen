guard :rspec, bundler: false do
  watch(%r{^spec/.+_spec\.rb$})
  watch(%r{^lib/(.+)\.rb$})                { |m| "spec/lib/#{m[1]}_spec.rb" }
  watch('spec/support/adapter_helper.rb')  { 'spec/lib/listen/adapter' }
  watch('spec/support/listener_helper.rb') { 'spec/lib/listen/listener_spec.rb' }
  watch('spec/support/fixtures_helper.rb') { 'spec' }
  watch('spec/spec_helper.rb')             { 'spec' }
end
