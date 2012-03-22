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

  # Listens to filesystem modifications on a single directory.
  #
  # @param (see Listen::Listener#new)
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

  # Listens to filesystem modifications on multiple directories.
  #
  # @param (see Listen::MultiListener#new)
  #
  # @yield [modified, added, removed] the changed files
  # @yieldparam [Array<String>] modified the list of modified files
  # @yieldparam [Array<String>] added the list of added files
  # @yieldparam [Array<String>] removed the list of removed files
  #
  # @return [Listen::MultiListener] the file listener if no block given
  #
  def self.to_each(*args, &block)
    listener = MultiListener.new(*args, &block)
    block ? listener.start : listener
  end

end
