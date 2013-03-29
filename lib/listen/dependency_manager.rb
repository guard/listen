require 'set'

module Listen

  # The dependency-manager offers a simple DSL which allows
  # classes to declare their gem dependencies and load them when
  # needed.
  # It raises a user-friendly exception when the dependencies
  # can't be loaded which has the install command in the message.
  #
  module DependencyManager

    GEM_LOAD_MESSAGE = <<-EOS.gsub(/^ {6}/, '')
      Missing dependency '%s' (version '%s')!
    EOS

    GEM_INSTALL_COMMAND = <<-EOS.gsub(/^ {6}/, '')
      Please run the following to satisfy the dependency:
        gem install %s --version %s
    EOS

    BUNDLER_DECLARE_GEM = <<-EOS.gsub(/^ {6}/, '')
      Please add the following to your Gemfile to satisfy the dependency:
        gem '%s', '%s'
    EOS

    Dependency = Struct.new(:name, :version)

    # The error raised when a dependency can't be loaded.
    class Error < StandardError; end

    # A list of all loaded dependencies in the dependency manager.
    @_loaded_dependencies = Set.new

    # Class methods
    class << self

      # Initializes the extended class.
      #
      # @param [Class] base the class for which some dependencies must be managed
      #
      def extended(base)
        base.class_eval do
          @_dependencies = Set.new
        end
      end

      # Adds a loaded dependency to a list so that it doesn't have
      # to be loaded again by another classes.
      #
      # @param [Dependency] dependency
      #
      def add_loaded(dependency)
        @_loaded_dependencies << dependency
      end

      # Returns whether the dependency is already loaded or not.
      #
      # @param [Dependency] dependency
      # @return [Boolean] whether the dependency is already loaded or not
      #
      def already_loaded?(dependency)
        @_loaded_dependencies.include?(dependency)
      end

      # Clears the list of loaded dependencies.
      #
      def clear_loaded
        @_loaded_dependencies.clear
      end
    end

    # Registers a new dependency.
    #
    # @param [String] name the name of the gem
    # @param [String] version the version of the gem
    #
    def dependency(name, version)
      @_dependencies << Dependency.new(name, version)
    end

    # Loads the registered dependencies.
    #
    # @raise DependencyManager::Error if any dependency can't be loaded.
    #
    def load_dependencies
      @_dependencies.each do |dependency|
        load(dependency)
      end
      true
    end

    # Returns whether all the dependencies have been loaded or not.
    #
    # @return [Boolean]
    #
    def dependencies_loaded?
      @_dependencies.empty?
    end

    private

    # Returns whether we are running under bundler or not
    #
    # @return [Boolean]
    #
    def running_under_bundler?
      !!(File.exists?('Gemfile') && ENV['BUNDLE_GEMFILE'])
    end

    # Loads the given dependency.
    #
    # @raise DependencyManager::Error if the dependency can't be loaded.
    #
    def load(dependency)
      begin
        return if DependencyManager.already_loaded?(dependency)

        gem dependency.name, dependency.version
        require dependency.name

        add_loaded(dependency)
      rescue Gem::LoadError
        raise_loading_error(dependency)
      end
    end

    def add_loaded(dependency)
      DependencyManager.add_loaded(@_dependencies.delete(dependency))
    end

    # Raises a DependencyManager::Error for the given dependency.
    #
    # @raise DependencyManager::Error
    #
    def raise_loading_error(dependency)
      args = [dependency.name, dependency.version]*2
      install_command = if running_under_bundler?
         BUNDLER_DECLARE_GEM
      else
        args.last.gsub!(/~?>=?\s+/, '')
        GEM_INSTALL_COMMAND
      end

      raise Error.new("#{GEM_LOAD_MESSAGE}#{install_command}" % args)
    end

  end
end
