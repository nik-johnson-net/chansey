require 'chansey/module'
require 'chansey/modules/irc/scheduled_connection'
require 'chansey/modules/irc/handlers/autojoin'
require 'chansey/modules/irc/handlers/ping'

module Chansey
  module Modules
    module Irc
      class Client < Chansey::Module
        DEFAULT_IRC_PORT        = 6667
        DEFAULT_RECONNECT_DELAY = 5

        def initialize(core, address, port=DEFAULT_IRC_PORT, autojoin=[])
          super(core)

          @address                  = address
          @connection               = nil
          @next_connection_attempt  = Time.now
          @port                     = port
          @autojoin_channels        = autojoin
        end

        def post_init
          connect
        end

        def send(message)
          if @connection
            @connection.send_data message

            true
          else
            false
          end
        end

        private
        def connect 
          handlers = [
            Irc::Handlers::Ping.new,
            Irc::Handlers::Autojoin.new(@autojoin_channels),
          ]

          completion = Irc::ScheduledConnection.new(@address, @port, @next_connection_attempt, handlers)
          completion.completion do |type, arg|
            case type
            when :succeeded
              @connection = arg
            when :failed
              connect
            end
          end

          @next_connection_attempt = Time.now + DEFAULT_RECONNECT_DELAY
        end
      end
    end
  end
end
