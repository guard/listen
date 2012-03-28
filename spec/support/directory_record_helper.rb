# Prepares a record for the test and fetches changes
# afterwards.
#
# @param [String] root_path the path to watch
# @param [Hash] options
# @option options [Array<string>] :paths optional paths fetch changes for
# @option options [Boolean] :use_last_record allow the use of an already
#   created record, handy for ordered tests.
#
# @return [Array, Array, Array] the changes
#
def changes(root_path, options = {})
  unless @record || options[:use_last_record]
    @record = Listen::DirectoryRecord.new(root_path)
    @record.build
    @record.filter(options.delete(:filter)) if options[:filter]
    @record.ignore(options.delete(:ignore)) if options[:ignore]
  end

  yield

  paths = options.delete(:paths) || [root_path]
  options[:recursive] = true if options[:recursive].nil?

  changes = @record.fetch_changes(paths, {:relative_paths => true}.merge(options))

  [changes[:modified], changes[:added], changes[:removed]]
end

def ensure_same_second
  t = Time.now
  if t.to_f - t.to_i > 0.1
    sleep 1.5 - (t.to_f - t.to_i)
  end
end
