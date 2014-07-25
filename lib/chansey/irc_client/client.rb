require 'chansey/irc_client/connection_monitor'

module Chansey
  module IrcClient
    class Client
      DEFAULT_IRC_PORT = 6667

      def initialize(config, router, log)
        @config = config
        @connections = {}
        @log = log
        @router = router
      end

      def connect(network)
        case x = @connections[network]
        when nil
          @log.debug("Starting connection attempt for #{network}")

          @connections[network] = ConnectionMonitor.new(@config.fetch(network), @log) do |msg, ctx|
            route(msg, ctx)
          end
        when x.class == ConnectionMonitor
          x
        end
      end

      private
      def route(msg, ctx)
        path = "irc/#{msg[:command]}"
        @router.route(path, msg, ctx)
      end
    end
  end
end
