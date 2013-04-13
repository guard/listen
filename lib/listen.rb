module Listen

  autoload :Turnstile,         'listen/turnstile'
  autoload :Listener,          'listen/listener'
  autoload :MultiListener,     'listen/multi_listener'
  autoload :DirectoryRecord,   'listen/directory_record'
  autoload :DependencyManager, 'listen/dependency_manager'
  autoload :Adapter,           'listen/adapter'

  module Adapters
    Adapter::ADAPTERS.each do |adapter|
      autoload adapter.to_sym, "listen/adapters/#{adapter.downcase}"
    end
  end

  # Listens to file system modifications on a either single directory or multiple directories.
  # When calling this method, the current thread is not blocked.
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
    listener = _init_listener(*args, &block)

    block ? listener.start : listener
  end

  # Listens to file system modifications on a either single directory or multiple directories.
  # When calling this method, the current thread is blocked.
  #
  # @param (see Listen::Listener#new)
  #
  # @yield [modified, added, removed] the changed files
  # @yieldparam [Array<String>] modified the list of modified files
  # @yieldparam [Array<String>] added the list of added files
  # @yieldparam [Array<String>] removed the list of removed files
  #
  # @since 1.0.0
  #
  def self.to!(*args, &block)
    _init_listener(*args, &block).start!
  end

  # @private
  #
  def self._init_listener(*args, &block)
    Listener.new(*args, &block)
  end

end
