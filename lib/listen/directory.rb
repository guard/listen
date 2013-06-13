module Listen
  class Directory
    attr_accessor :path, :options

    def initialize(path, options = {})
      @path    = path
      @options = options
    end

    def scan
      _all_entries.each do |entry_path, data|
        case data[:type]
        when 'File' then _async_change(entry_path, type: 'File')
        when 'Dir'
          _async_change(entry_path, options.merge(type: 'Dir')) if options[:recursive]
        end
      end
    end

    private

    def _all_entries
      _record_entries.merge(_entries)
    end

    def _entries
      return {} unless ::Dir.exists?(path)
      entries = ::Dir.entries(path) - %w[. ..]
      entries = entries.map { |entry| [entry, type: _entry_type(entry)] }
      Hash[*entries.flatten]
    end

    def _entry_type(entry_path)
      entry_path = path.join(entry_path)
      if entry_path.file?
        'File'
      elsif entry_path.directory?
        'Dir'
      end
    end

    def _record_entries
      future = _record.future.dir_entries(path)
      future.value
    end

    def _record
      Celluloid::Actor[:record]
    end

    def _change_pool
      Celluloid::Actor[:change_pool]
    end

    def _async_change(entry_path, options)
      entry_path = path.join(entry_path)
      _change_pool.async.change(entry_path, options)
    end
  end
end




















#     # attr_reader :directory, :paths, :sha1_checksums
#     # Finds the paths that should be stored and adds them
#     # to the paths' hash.
#     #
#     def build
#       @paths = Hash.new { |h, k| h[k] = Hash.new }
#       important_paths { |path| insert_path(path) }
#     end

#     # Detects changes in the passed directories, updates
#     # the record with the new changes and returns the changes.
#     #
#     # @param [Array] directories the list of directories to scan for changes
#     # @param [Hash] options
#     # @option options [Boolean] recursive scan all sub-directories recursively
#     # @option options [Boolean] relative_paths whether or not to use relative paths for changes
#     #
#     # @return [Hash<Array>] the changes
#     #
#     def fetch_changes(directories, options = {})
#       @changes    = { modified: [], added: [], removed: [] }
#       directories = directories.sort_by { |el| el.length }.reverse # diff sub-dir first

#       directories.each do |directory|
#         next unless directory[@directory] # Path is or inside directory

#         detect_modifications_and_removals(directory, options)
#         detect_additions(directory, options)
#       end

#       @changes
#     end

#     # Converts an absolute path to a path that's relative to the base directory.
#     #
#     # @param [String] path the path to convert
#     #
#     # @return [String] the relative path
#     #
#     def relative_to_base(path)
#       return nil unless path[directory]

#       path = path.force_encoding("BINARY") if path.respond_to?(:force_encoding)
#       path.sub(%r{^#{Regexp.quote(directory)}#{File::SEPARATOR}?}, '')
#     end

#     private

#     # Detects modifications and removals recursively in a directory.
#     #
#     # @note Modifications detection begins by checking the modification time (mtime)
#     #   of files and then by checking content changes (using SHA1-checksum)
#     #   when the mtime of files is not changed.
#     #
#     # @param [String] directory the path to analyze
#     # @param [Hash] options
#     # @option options [Boolean] recursive scan all sub-directories recursively
#     # @option options [Boolean] relative_paths whether or not to use relative paths for changes
#     #
#     def detect_modifications_and_removals(directory, options = {})
#       paths[directory].each do |basename, meta_data|
#         path = File.join(directory, basename)
#         case meta_data.type
#         when 'Dir'
#           detect_modification_or_removal_for_dir(path, options)
#         when 'File'
#           detect_modification_or_removal_for_file(path, meta_data, options)
#         end
#       end
#     end

#     def detect_modification_or_removal_for_dir(path, options)

#       # Directory still exists
#       if File.directory?(path)
#         detect_modifications_and_removals(path, options) if options[:recursive]

#       # Directory has been removed
#       else
#         detect_modifications_and_removals(path, options)
#         @paths[File.dirname(path)].delete(File.basename(path))
#         @paths.delete("#{File.dirname(path)}/#{File.basename(path)}")
#       end
#     end

#     def detect_modification_or_removal_for_file(path, meta_data, options)
#       # File still exists
#       if File.exist?(path)
#         detect_modification(path, meta_data, options)

#       # File has been removed
#       else
#         removal_detected(path, meta_data, options)
#       end
#     end

#     def detect_modification(path, meta_data, options)
#       new_mtime = mtime_of(path)

#       # First check if we are in the same second (to update checksums)
#       # before checking the time difference
#       if (meta_data.mtime.to_i == new_mtime.to_i && content_modified?(path)) || meta_data.mtime < new_mtime
#         modification_detected(path, meta_data, new_mtime, options)
#       end
#     end

#     def modification_detected(path, meta_data, new_mtime, options)
#       # Update the sha1 checksum of the file
#       update_sha1_checksum(path)

#       # Update the meta data of the file
#       meta_data.mtime = new_mtime
#       @paths[File.dirname(path)][File.basename(path)] = meta_data

#       @changes[:modified] << (options[:relative_paths] ? relative_to_base(path) : path)
#     end

#     def removal_detected(path, meta_data, options)
#       @paths[File.dirname(path)].delete(File.basename(path))
#       @sha1_checksums.delete(path)
#       @changes[:removed] << (options[:relative_paths] ? relative_to_base(path) : path)
#     end

#     # Detects additions in a directory.
#     #
#     # @param [String] directory the path to analyze
#     # @param [Hash] options
#     # @option options [Boolean] recursive scan all sub-directories recursively
#     # @option options [Boolean] relative_paths whether or not to use relative paths for changes
#     #
#     def detect_additions(directory, options = {})
#       # Don't process removed directories
#       return unless File.exist?(directory)

#       Find.find(directory) do |path|
#         next if path == @directory

#         if File.directory?(path)
#           # Add a trailing slash to directories when checking if a directory is
#           # ignored to optimize finding them as Find.find doesn't.
#           if ignored?(path + File::SEPARATOR) || (directory != path && (!options[:recursive] && existing_path?(path)))
#             Find.prune # Don't look any further into this directory.
#           else
#             insert_path(path)
#           end
#         elsif !ignored?(path) && filtered?(path) && !existing_path?(path)
#           if File.file?(path)
#             @changes[:added] << (options[:relative_paths] ? relative_to_base(path) : path)
#             insert_path(path)
#           end
#         end
#       end
#     end

#     # Traverses the base directory looking for paths that should
#     # be stored; thus paths that are filtered or not ignored.
#     #
#     # @yield [path] an important path
#     #
#     def important_paths
#       Find.find(directory) do |path|
#         next if path == directory

#         if File.directory?(path)
#           # Add a trailing slash to directories when checking if a directory is
#           # ignored to optimize finding them as Find.find doesn't.
#           if ignored?(path + File::SEPARATOR)
#             Find.prune # Don't look any further into this directory.
#           else
#             yield(path)
#           end
#         elsif !ignored?(path) && filtered?(path)
#           yield(path)
#         end
#       end
#     end

#     # Inserts a path with its type (Dir or File) in paths hash.
#     #
#     # @param [String] path the path to insert in @paths.
#     #
#     def insert_path(path)
#       meta_data = MetaData.new
#       meta_data.type = File.directory?(path) ? 'Dir' : 'File'
#       meta_data.mtime = mtime_of(path) unless meta_data.type == 'Dir' # mtimes of dirs are not used yet
#       @paths[File.dirname(path)][File.basename(path)] = meta_data
#     rescue Errno::ENOENT
#     end

#     # Returns whether or not a path exists in the paths hash.
#     #
#     # @param [String] path the path to check
#     #
#     # @return [Boolean]
#     #
#     def existing_path?(path)
#       paths[File.dirname(path)][File.basename(path)] != nil
#     end
#   end
# end
