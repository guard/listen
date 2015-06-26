ignore(%r{spec/\.fixtures/})

group :specs, halt_on_fail: true do
  guard :rspec, cmd: 'bundle exec rspec -t ~acceptance', failed_mode: :keep, all_after_pass: true do
    watch(%r{^spec/lib/.+_spec\.rb$})
    watch(%r{^lib/(.+)\.rb$})     { |m| "spec/lib/#{m[1]}_spec.rb" }
    watch(%r{^spec/support/*})    { 'spec' }
    watch('spec/spec_helper.rb')  { 'spec' }
  end

  guard :rubocop, all_on_start: false, cli: '--rails' do
    watch(%r{.+\.rb$}) { |m| m[0] }
    watch(%r{(?:.+/)?\.rubocop\.yml$}) { |m| File.dirname(m[0]) }
    watch(%r{(?:.+/)?\.rubocop_todo\.yml$}) { |m| File.dirname(m[0]) }
  end

  # TODO: guard rspec should have a configurable file for this to work
  # TODO: also split up Rakefile
  guard :rspec, cmd: 'bundle exec rspec -t acceptance', failed_mode: :keep, all_after_pass: true do
    watch(%r{^spec/lib/.+_spec\.rb$})
    watch(%r{^lib/(.+)\.rb$})     { |m| "spec/lib/#{m[1]}_spec.rb" }
    watch(%r{^spec/support/*})    { 'spec' }
    watch('spec/spec_helper.rb')  { 'spec' }
    watch(%r{^spec/acceptance/.+_spec\.rb$})
  end
end
