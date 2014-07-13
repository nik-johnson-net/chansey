module Chansey
  module IRC
    module Client
      class Server
        def initialize(connection, config)
          @config = config
          @connection = connection
          @connection.on_message(&on_method)
        end

        private
        def on_message(message)
        end
      end
    end
  end
end
