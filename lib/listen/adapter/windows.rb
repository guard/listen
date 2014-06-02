module Listen
  module Adapter
    # Adapter implementation for Windows `wdm`.
    #
    class Windows < Base
      OS_REGEXP = /mswin|mingw|cygwin/i

      BUNDLER_DECLARE_GEM = <<-EOS.gsub(/^ {6}/, '')
        Please add the following to your Gemfile to avoid polling for changes:
          require 'rbconfig'
          if RbConfig::CONFIG['target_os'] =~ /mswin|mingw|cygwin/i
            gem 'wdm', '>= 0.1.0'
          end
      EOS

      def self.usable?
        return false unless super
        require 'wdm'
        true
      rescue LoadError
        _log :debug, "wdm - load failed: #{$!}:#{$@.join("\n")}"
        Kernel.warn BUNDLER_DECLARE_GEM
        false
      end

      private

      def _configure(dir, &callback)
        require 'wdm'
        _log :debug, 'wdm - starting...'
        @worker ||= WDM::Monitor.new
        @worker.watch_recursively(dir.to_s, :files) do |change|
          callback.call([:file, change])
        end

        @worker.watch_recursively(dir.to_s, :directories) do |change|
          callback.call([:dir, change])
        end

        events = [:attributes, :last_write]
        @worker.watch_recursively(dir.to_s, *events) do |change|
          callback.call([:attr, change])
        end
      end

      def _run
        @worker.run!
      end

      def _process_event(directory, event, new_changes)
        _log :debug, "wdm - callback: #{event.inspect}"

        type, change = event

        full_path = Pathname(change.path)

        rel_path = full_path.relative_path_from(directory)

        options = { change: _change(change.type) }

        case type
        when :file
          new_changes << [:file, rel_path, options]
        when :attr
          unless full_path.directory?
            new_changes << [:file, rel_path, options]
          end
        when :dir
          if change.type == :removed
            new_changes << [:dir, rel_path.dirname]
          elsif change.type == :added
            new_changes << [:dir, rel_path]
          else
            # do nothing - changed directory means either:
            #   - removed subdirs (handled above)
            #   - added subdirs (handled above)
            #   - removed files (handled by _file_callback)
            #   - added files (handled by _file_callback)
            # so what's left?
          end
        end
      rescue
        details = event.inspect
        _log :error, "wdm - callback (#{details}): #{$!}:#{$@.join("\n")}"
        raise
      end

      def _change(type)
        { modified: [:modified, :attrib], # TODO: is attrib really passed?
          added:    [:added, :renamed_new_file],
          removed:  [:removed, :renamed_old_file] }.each do |change, types|
          return change if types.include?(type)
        end
        nil
      end
    end
  end
end
