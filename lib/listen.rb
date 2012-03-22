module Listen

  autoload :Turnstile,       'listen/turnstile'
  autoload :Listener,        'listen/listener'
  autoload :MultiListener,   'listen/multi_listener'
  autoload :DirectoryRecord, 'listen/directory_record'
  autoload :Adapter,         'listen/adapter'

  module Adapters
    autoload :Darwin,  'listen/adapters/darwin'
    autoload :Linux,   'listen/adapters/linux'
    autoload :Windows, 'listen/adapters/windows'
    autoload :Polling, 'listen/adapters/polling'
  end

  # Listen to file system modifications.
  #
  # @param [String, Pathname] dir the directory to watch
  # @param [Hash] options the listen options
  # @option options [String] ignore a list of paths to ignore
  # @option options [Regexp] filter a list of regexps file filters
  # @option options [Float] latency the delay between checking for changes in seconds
  # @option options [Boolean] polling whether to force or disable the polling adapter
  #
  # @yield [modified, added, removed] the changed files
  # @yieldparam [Array<String>] modified the list of modified files
  # @yieldparam [Array<String>] added the list of added files
  # @yieldparam [Array<String>] removed the list of removed files
  #
  # @return [Listen::Listener] the file listener if no block given
  #
  def self.to(*args, &block)
    listener = Listener.new(*args, &block)
    block ? listener.start : listener
  end

end
