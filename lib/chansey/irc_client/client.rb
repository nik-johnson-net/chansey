require 'chansey/irc_client/connection_monitor'

module Chansey
  module IrcClient
    class Client
      DEFAULT_IRC_PORT = 6667

      def initialize(config, log)
        @config = config
        @connections = {}
        @log = log
        @handler = lambda { }
      end

      def connect(network)
        case x = @connections[network]
        when nil
          @log.debug("Starting connection attempt for #{network}")

          @connections[network] = ConnectionMonitor.new(@config.fetch(network), @log) do |msg, ctx|
            @handler.call(msg, ctx)
          end
        when x.class == ConnectionMonitor
          x
        end
      end

      def handler(&block)
        @handler = block
      end
    end
  end
end
