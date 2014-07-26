require 'em/deferrable'
require 'chansey/irc_client/connection'
require 'chansey/irc_client/server'

module Chansey
  module IrcClient
    class ConnectionMonitor
      DEFAULT_IRC_PORT = 6667
      CONNECTION_DELAY_SECONDS = 5

      def initialize(config, log, &block)
        @config = config
        @log = log
        @handler = block
        @server_counter = 0
        @next_attempt = Time.now

        schedule_attempt
      end

      private
      def schedule_attempt
        delay = (@next_attempt - Time.now).to_i
        @connection_deferrable = EventMachine::DefaultDeferrable.new

        if delay > 0
          @log.debug "Scheduling connection attempt in #{delay} seconds"
          EventMachine.add_timer(delay) do
            start_attempt
          end
        else
          start_attempt
        end
      end

      def start_attempt
        @log.debug "Starting new connection attempt"
        @next_attempt = Time.now + 5
        resolve_address *pick_server
      end

      def pick_server
        servers = @config.fetch('servers')
        server = servers[@server_counter]

        # Move server_counter to point to the next server to try
        @server_counter = (@server_counter + 1) % servers.length

        address, port = server.split(':', 2)
        port ||= DEFAULT_IRC_PORT

        [address, port]
      end

      def resolve_address(address, port)
        @log.debug "Attempting to resolve address: #{address}"
        dns_deferrable = EventMachine::DNS::Resolver.resolve(address)

        dns_deferrable.callback do |results|
          ip_address = results.first

          connect(ip_address, port)
        end

        dns_deferrable.errback do
          @log.error "Failed to look up #{address}."
          schedule_attempt
        end

        nil
      end

      def connect(address, port)
        @log.debug "Connecting to #{address}:#{port}"

        EventMachine.connect(address, port, Connection, @config, @log) do |c|
          connection_complete_deferrable = c.connected

          connection_complete_deferrable.callback do
            @log.info "Connected to #{address}:#{port}"
            handoff(c)
          end

          connection_complete_deferrable.errback do
            @log.error "Connection failed to #{address}:#{port}"
            schedule_attempt
          end
        end

        nil
      end

      def handoff(connection)
        Server.new(connection, @config) do |success, server|
          if success
            @log.info "Registered"
            server.handler(&@handler)
            @connection_deferrable.succeed(server)
          else
            @log.error "Registration failed to #{address}:#{port}"
            schedule_attempt
          end
        end

        nil
      end
    end
  end
end
