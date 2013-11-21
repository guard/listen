module Listen
  module Adapter

    # Adapter implementation for Windows `wdm`.
    #
    class Windows < Base

      # The message to show when wdm gem isn't available
      #
      BUNDLER_DECLARE_GEM = <<-EOS.gsub(/^ {6}/, '')
        Please add the following to your Gemfile to avoid polling for changes:
          require 'rbconfig'
          gem 'wdm', '>= 0.1.0' if RbConfig::CONFIG['target_os'] =~ /mswin|mingw|cygwin/i
      EOS

      def self.usable?
        if RbConfig::CONFIG['target_os'] =~ /mswin|mingw|cygwin/i
          require 'wdm'
          true
        end
      rescue LoadError
        Kernel.warn BUNDLER_DECLARE_GEM
        false
      end

      def start
        worker = _init_worker
        Thread.new { worker.run! }
      end

      private

      # Initializes a WDM monitor and adds a watcher for
      # each directory passed to the adapter.
      #
      # @return [WDM::Monitor] initialized worker
      #
      def _init_worker
        WDM::Monitor.new.tap do |worker|
          _directories_path.each { |path| worker.watch_recursively(path, &_worker_callback) }
        end
      end

      def _worker_callback
        lambda do |change|
            _notify_change(_path(change.path), type: 'File', change: _change(change.type))
        end
      end

      def _path(path)
        Pathname.new(path)
      end

      def _change(type)
        { modified: [:modified],
          added:    [:added, :renamed_new_file],
          removed:  [:removed, :renamed_old_file] }.each do |change, types|
          return change if types.include?(type)
        end
        nil
      end
    end

  end
end
