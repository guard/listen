module Listener

  # Listen to file system modifications.
  #
  # @param [String, Pathname] dir the directory to watch
  # @param [Hash] options the listen options
  # @option options [String] glob the file filter pattern
  # @yield [modified, added, removed] the changed files
  # @yieldparam [Array<String>] modified the list of modified files
  # @yieldparam [Array<String>] added the list of added files
  # @yieldparam [Array<String>] removed the list of removed files
  # @return [Watcher] the file watcher
  #
  def self.listen(dir, options, &block)
  end

end
