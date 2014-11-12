require 'thor'
require 'listen'
require 'logger'

module Listen
  class CLI < Thor
    default_task :start

    desc 'start', 'Starts Listen'

    class_option :verbose,
                 type:    :boolean,
                 default: false,
                 aliases: '-v',
                 banner:  'Verbose'

    class_option :forward,
                 type:    :string,
                 default: '127.0.0.1:4000',
                 aliases: '-f',
                 banner:  'The address to forward filesystem events'

    class_option :directory,
                 type:    :string,
                 default: '.',
                 aliases: '-d',
                 banner:  'The directory to listen to'

    def start
      Listen::Forwarder.new(options).start
    end
  end

  class Forwarder
    attr_reader :logger
    def initialize(options)
      @options = options
      @logger = Logger.new(STDOUT)
      @logger.level = Logger::INFO
      @logger.formatter = proc { |_, _, _, msg| "#{msg}\n" }
    end

    def start
      logger.info 'Starting listen...'
      address = @options[:forward]
      directory = @options[:directory]
      callback = proc do |modified, added, removed|
        if @options[:verbose]
          logger.info "+ #{added}" unless added.empty?
          logger.info "- #{removed}" unless removed.empty?
          logger.info "> #{modified}" unless modified.empty?
        end
      end

      listener = Listen.to directory, forward_to: address, &callback
      listener.start

      sleep 0.5 while listener.listen?
    end
  end
end
