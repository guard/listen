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
    @record.filter(options.delete(:filter)) if options[:filter]
    @record.ignore(options.delete(:ignore)) if options[:ignore]

    # Build the record after adding the filtering and ignoring patterns
    @record.build
  end

  yield

  paths = options.delete(:paths) || [root_path]
  options[:recursive] = true if options[:recursive].nil?

  changes = @record.fetch_changes(paths, {:relative_paths => true}.merge(options))

  [changes[:modified], changes[:added], changes[:removed]]
end

# Generates a small time difference (less than 1 second on Linux
# and less than 1.5 seconds on Mac and Windows).
def small_time_difference
  t = Time.now
  diff = t.to_f - t.to_i
  # Modification time for files on Mac and Windows does NOT include the milliseconds.
  # That's why we add an extra half second for tests on those systems.
  sleep( (linux? ? 1 : 1.5) - (diff > 0.1 ? diff : 0.1) )
end
