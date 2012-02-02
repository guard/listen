# Adapter watch
#
# @param [Listen::Listener] listener the adapter listener
# @param [String] path the path to watch
#
def watch(listener, path)
  listener.stub(:directory) { path }
  adapter = Listen::Adapter.select_and_initialize(listener)

  sleep 0.15 # manage adapter latency
  Thread.new { adapter.start }
  sleep 0.1 # wait for adapter to start
  yield
  sleep 0.15 # manage adapter latency
end
