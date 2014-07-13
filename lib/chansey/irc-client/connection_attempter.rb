require 'eventmachine/deferrable'
require 'chansey/irc-client/connection'

module Chansey
  module IRC
    module Client
      class ConnectionAttempter
        include EventMachine::Deferrable

        DEFAULT_IRC_PORT = 6667
        CONNECTION_DELAY_SECONDS = 5

        def initialize(config)
          @config = config
          @server_counter = 0
          @next_attempt = Time.now
        end

        private
        def schedule_attempt
          delay = (Time.now - @next_attempt).to_i

          if delay > 0
            EventMachine.add_timer(delay) do
              start_attempt
            end
          else
            start_attempt
          end
        end

        def start_attempt
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
          dns_deferrable = EventMachine::DNS::Resolver.resolve(address)

          dns_deferrable.callback do |results|
            ip_address = results.first

            connect(ip_address, port)
          end

          dns_deferrable.errback do
            schedule_attempt
          end

          nil
        end

        def connect(address, port)
          EventMachine.connect(address, port, Connection, @config) do |c|
            d = c.connected

            d.callback do
              succeed Server.new(c, @config)
            end

            d.errback do
              schedule_attempt
            end
          end

          nil
        end
      end
    end
  end
end
