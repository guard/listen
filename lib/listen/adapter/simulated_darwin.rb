module Listen
  module Adapter
    class SimulatedDarwin < Linux
      def self.usable?
        os = RbConfig::CONFIG['target_os']
        return false unless const_get('OS_REGEXP') =~ os
        /1|true/ =~ ENV['LISTEN_GEM_SIMULATE_FSEVENT']
      end

      class FakeEvent
        attr_reader :dir

        def initialize(watched_dir, event)
          # NOTE: avoid using event.absolute_name since new API
          # will need to have a custom recursion implemented
          # to properly match events to configured directories
          @real_path = full_path(event).relative_path_from(watched_dir)
          @dir = "#{Pathname(watched_dir) + dir_for_event(event, @real_path)}/"
        end

        def real_path
          @real_path.to_s
        end

        private

        def dir?(event)
          event.flags.include?(:isdir)
        end

        def moved?(event)
          (event.flags & [:moved_to, :moved_from])
        end

        def dir_for_event(event, rel_path)
          (moved?(event) || dir?(event)) ?  rel_path.dirname : rel_path
        end

        def full_path(event)
          Pathname.new(event.watcher.path) + event.name
        end
      end

      private

      def _process_event(watched_dir, event)
        ev = FakeEvent.new(watched_dir, event)

        _log(
          :debug,
          "fake_fsevent: #{ev.dir}(#{ev.real_path}=#{event.flags.inspect})")

        _darwin.send(:_process_event, watched_dir, [ev.dir])
      end

      def _darwin
        @darwin ||= Class.new(Darwin) do
          def _configure(*_args)
            # Skip FSEvent setup
          end
        end.new(mq: @mq)
      end
    end
  end
end
