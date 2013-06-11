# #!/Users/Thibaud/.rbenv/shims/ruby
# require 'celluloid'

# class Listener
#   include Celluloid

#   def initialize
#     Adapter.supervise_as(:adapter)
#     @messages = Queue.new
#     async.wait_for_messages
#   end

#   def wait_for_messages
#     loop { @messages << receive }
#   end

#   def poll_messages
#     every(1) do
#       array = []
#       array << @messages.pop until @messages.empty?
#       p array
#     end
#   end

# end

# class Adapter
#   include Celluloid
#   attr_accessor :recursive

#   def initialize
#     @recursive = false
#     async.listen
#   end

#   def listen
#     # loop do
#     #   sleep 10
#     # end
#     # loop do
#     #   sleep 0.3
#     #   # raise if [false, true].sample
#     #   Actor[:listener].mailbox << ["yo"]
#     # end
#   end
# end

# Celluloid::Actor[:listener] = Listener.new
# Celluloid::Actor[:listener].poll_messages
# p "before"
# p Celluloid::Actor[:adapter].recursive
# p "after"
# sleep

require 'listen'

Listen.to(Dir.pwd) do |modified, added, removed|
  p "---------------------"
  p "modified: #{modified}"
  p "added   : #{added}"
  p "removed : #{removed}"
end

sleep

