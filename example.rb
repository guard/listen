require 'listen'

listener = Listen.to(Dir.pwd, force_polling: true) do |modified, added, removed|
  p "---------------------"
  p "modified: #{modified}"
  p "added   : #{added}"
  p "removed : #{removed}"
end
listener.start
sleep

