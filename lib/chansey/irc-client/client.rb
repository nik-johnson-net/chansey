require 'chansey/irc-client/connection_attempter'

module Chansey
  module IRC
    module Client
      class Client
        DEFAULT_IRC_PORT = 6667

        def initialize(config, log)
          @config = config
          @connections = {}
          @log = log
        end

        def connect(network)
          case x = @connections[network]
          when nil
            @log.debug("Starting connection attempt for #{network}")
            @connections[network] = ConnectionAttempter.new(@config.fetch(network), log)
          when x.class == ConnectionAttempter
            x
          end
        end
      end
    end
  end
end
