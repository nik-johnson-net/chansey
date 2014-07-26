module Chansey
  module IrcClient
    class Server
      attr_reader :network
      attr_reader :current_nick

      # Block is called upon successful registration
      def initialize(network, connection, config, &block)
        @config = config
        @connection = connection
        @connection.handler = method(:on_message)
        @current_nick = @config['nick']
        @handler = lambda { |m,c| }
        @network = network
        @on_registration_callback = block

        @connection.send_data "NICK #{@current_nick}"
        @connection.send_data "USER #{@current_nick} 8 * :#{@config['fullname']}"
      end

      def handler(&block)
        @handler = block
      end

      def send(msg)
        @connection.send_data(msg)
      end

      private
      def on_message(message, connection)
        case message[:command]
        when :'001'
          @on_registration_callback.call(true, self)
          @config['channels'].each { |chan| send("JOIN #{chan}") }
        when :ping
          @connection.send_data "PONG :#{message[:trailing]}"
        end

        @handler.call(message, self)
      end
    end
  end
end
