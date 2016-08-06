module Listen
  # @private api
  module Internals
    module ThreadPool
      def self.add(&block)
        stack = caller
        Thread.new { block.call }.tap do |th|
          th[:stack] = stack
          (@threads ||= Queue.new) << th
        end
      end

      def self.stop
        return unless @threads ||= nil
        return if @threads.empty? # return to avoid using possibly stubbed Queue

        initial_threads = []

        killed = Queue.new
        killed << @threads.pop.tap do |th|
          initial_threads << th
          safe_wakeup(th)
          safe_join(th)
          th.kill
          safe_wakeup(th)
        end until @threads.empty?

        until killed.empty?
          safe_join(killed.pop)
        end

        remaining_threads = initial_threads & Thread.list
        return unless remaining_threads.any?

        STDERR.puts "BUG: Listen threads still running after stop:"

        remaining_threads.each do |th|
          STDERR.puts "Listen thread still running: #{th.inspect}"
          if th.backtrace
            STDERR.puts th.backtrace * "\n (thread backtrace)"
            STDERR.puts th[:stack] * "\n (thread.new caller)"
          else
            STDERR.puts "(no thread backtrace)"
          end
        end
      end

      # @private
      def self.safe_join(thread)
        # You can't kill a read on a descriptor in JRuby, so let's just
        # ignore running threads (listen rb-inotify waiting for disk activity
        # before closing)  pray threads die faster than they are created...
        limit = RUBY_ENGINE == 'jruby' ? [1] : []

        # rb-inotify can get stuck on readpartial, so give it some time, but
        # not too much
        timeout = thread[:listen_blocking_read_thread] ? [0.3] : limit
        thread.join(*timeout)
      end

      # @private
      def self.safe_wakeup(thread)
        thread.wakeup
      rescue ThreadError
      end
    end
  end
end
