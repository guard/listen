require 'listen/turnstile'
require 'listen/listener'
require 'listen/multi_listener'
require 'listen/directory_record'
require 'listen/adapter'

module Listen

  module Adapters
    Adapter::ADAPTERS.each do |adapter|
      require "listen/adapters/#{adapter.downcase}"
    end
  end

  # Listens to file system modifications on a either single directory or multiple directories.
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

end
