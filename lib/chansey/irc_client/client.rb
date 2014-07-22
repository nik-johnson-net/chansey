require 'chansey/irc_client/connection_monitor'

module Chansey
  module IrcClient
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
          @connections[network] = ConnectionMonitor.new(@config.fetch(network), @log)
        when x.class == ConnectionMonitor
          x
        end
      end
    end
  end
end
