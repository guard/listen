begin
  require 'celluloid/io'
rescue LoadError
  Kernel.fail 'TCP forwarding requires Celluloid::IO to be present. ' \
              "Please install or add as a dependency: gem 'celluloid-io'"
end

require 'listen/adapter/tcp'
