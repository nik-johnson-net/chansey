module Chansey
  module IrcClient
    class Server
      # Block is called upon successful registration
      def initialize(connection, config, &block)
        @config = config
        @connection = connection
        @connection.handler = method(:on_message)
        @on_registration_callback = block

        @connection.send_data "NICK #{@config['nick']}"
        @connection.send_data "USER #{@config['user']} 8 * :#{@config['fullname']}"
      end

      private
      def on_message(message, connection)
        case message[:command]
        when :'001'
          @on_registration_callback.call(true, self)
        when :ping
          @connection.send_data "PONG :#{message[:trailing]}"
        end
      end
    end
  end
end
