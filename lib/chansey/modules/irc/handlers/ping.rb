require 'chansey/modules/irc/handler'

module Chansey
  module Modules
    module Irc
      module Handlers
        class Ping
          include Irc::Handler

          PONG = 'PONG :%s'

          def receive_message(message, connection)
            case message[:command]
            when :ping
              connection.send_data(PONG % message[:trailing])
            end
          end
        end
      end
    end
  end
end
