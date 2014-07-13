require 'chansey/irc-client/connection_attempter'

module Chansey
  module IRC
    module Client
      class Client
        DEFAULT_IRC_PORT = 6667

        def initialize(config)
          @config = config
          @connections = {}
        end

        def connect(network)
          case x = @connections[network]
          when nil
            @connections[network] = ConnectionAttempter.new(@config.fetch(network))
          when x.class == ConnectionAttempter
            x
          end
        end
      end
    end
  end
end
