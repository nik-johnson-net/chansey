require 'chansey/modules/irc/connection'
require 'chansey/modules/irc/handler'

module Chansey
  module Modules
    module Irc
      class ScheduledConnection < EM::Completion
        # Internal class for handling registration
        class ConnectionCompletionHandler
          include Irc::Handler

          def initialize(completion)
            @completion
          end

          def registered(connection)
            @completion.succeed connection
          end

          def unbind
            @completion.fail 'Connection closed'
          end
        end

        def initialize(address, port, next_attempt, handlers)
          super()

          @address  = address
          @handlers = handlers
          @port     = port

          @handlers << ConnectionCompletionHandler.new(self)

          delay = (next_attempt - Time.now).to_i
          if delay > 0
            EM.add_timer(delay) do
              resolve_address
            end
          else
            resolve_address
          end
        end

        private
        def resolve_address
          dns_deferrable = EventMachine::DNS::Resolver.resolve(@address)
          dns_deferrable.callback do |results|
            ip_address = results.first
            EM.connect(ip_address, @port, Irc::Connection, @handlers)
          end

          dns_deferrable.errback do
            fail 'Could not resolve address'
          end

          nil
        end
      end
    end
  end
end
