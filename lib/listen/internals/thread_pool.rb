module Listen
  # @private api
  module Internals
    # Just a wrapper for tests to avoid interfereing with Celluloid's threads
    module ThreadPool
      def self.add(&block)
        (@threads ||= Queue.new) << Thread.new { block.call }
      end

      def self.stop
        return unless @threads ||= nil

        killed = Queue.new
        killed << @threads.pop.kill until @threads.empty?
        killed.pop.join until killed.empty?
      end
    end
  end
end
