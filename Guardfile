ignore(%r{spec/\.fixtures/})

group :specs, halt_on_fail: true do
  guard :rspec, cmd: 'bundle exec rspec', failed_mode: :keep do
    watch(%r{^spec/.+_spec\.rb$})
    watch(%r{^lib/(.+)\.rb$})     { |m| "spec/lib/#{m[1]}_spec.rb" }
    watch(%r{^spec/support/*})    { 'spec' }
    watch('spec/spec_helper.rb')  { 'spec' }
  end

  guard :rubocop, all_on_start: false, cli: '--rails' do
    watch(%r{.+\.rb$}) { |m| m[0] }
    watch(%r{(?:.+/)?\.rubocop\.yml$}) { |m| File.dirname(m[0]) }
    watch(%r{(?:.+/)?\.rubocop_todo\.yml$}) { |m| File.dirname(m[0]) }
  end
end
