module Listen
  # @private api
  module Internals
    module ThreadPool
      def self.add(&block)
        Thread.new { block.call }.tap do |th|
          (@threads ||= Queue.new) << th
        end
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
