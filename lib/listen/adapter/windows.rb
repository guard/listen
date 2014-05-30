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

      def _configure
        _log :debug, 'wdm - starting...'
        @worker = WDM::Monitor.new
        _directories.each do |path|
          @worker.watch_recursively(path.to_s, :files, &_file_callback)
          @worker.watch_recursively(path.to_s, :directories, &_dir_callback)
          @worker.watch_recursively(path.to_s, :attributes, :last_write,
                                    &_attr_callback)
        end
      end

      def _run
        @worker.run!
      end

      def _file_callback
        lambda do |change|
          begin
            path = _path(change.path)
            _log :debug, "wdm - FILE callback: #{change.inspect}"
            options = { change: _change(change.type) }
            _notify_change(:file, path, options)
          rescue
            _log :error, "wdm - callback failed: #{$!}:#{$@.join("\n")}"
            raise
          end
        end
      end

      def _attr_callback
        lambda do |change|
          begin
            path = _path(change.path)
            return if path.directory?

            _log :debug, "wdm - ATTR callback: #{change.inspect}"
            options = { change: _change(change.type) }
            _notify_change(:file, _path(change.path), options)
          rescue
            _log :error, "wdm - callback failed: #{$!}:#{$@.join("\n")}"
            raise
          end
        end
      end

      def _dir_callback
        lambda do |change|
          begin
            path = _path(change.path)
            _log :debug, "wdm - DIR callback: #{change.inspect}"
            if change.type == :removed
              _notify_change(:dir, path.dirname)
            elsif change.type == :added
              _notify_change(:dir, path)
            else
              # do nothing - changed directory means either:
              #   - removed subdirs (handled above)
              #   - added subdirs (handled above)
              #   - removed files (handled by _file_callback)
              #   - added files (handled by _file_callback)
              # so what's left?
            end
          rescue
            _log :error, "wdm - callback failed: #{$!}:#{$@.join("\n")}"
            raise
          end
        end
      end

      def _path(path)
        Pathname.new(path)
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
