require 'thor'
require 'listen'

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
    def initialize(options)
      @options = options
    end

    def start
      puts "Starting listen..."
      address = @options[:forward]
      directory = @options[:directory]
      callback = Proc.new do |modified, added, removed|
        if @options[:verbose]
          puts "+ #{added}" unless added.empty?
          puts "- #{removed}" unless removed.empty?
          puts "> #{modified}" unless modified.empty?
        end
      end

      listener = Listen.to directory, forward_to: address, &callback
      listener.start

      while listener.listen?
        sleep 0.5
      end
    end
  end
end
