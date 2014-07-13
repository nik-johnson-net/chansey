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
          when x.class == Server
            EventMachine::DefaultDeferrable.new.succeed(x)
          end
        end

        def disconnect(network)
          case x = @connections[network]
          when nil
          when x.class == ConnectionAttempter
          when x.class == Server
          end
        end

        def reconnect(network)
          case x = @connections[network]
          when nil
          when x.class == ConnectionAttempter
          when x.class == Server
          end
        end
      end
    end
  end
end
