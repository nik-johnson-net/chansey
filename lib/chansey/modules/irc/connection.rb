require 'eventmachine'

require 'chansey/irc/line_decoder'
require 'chansey/irc/irc_decoder'

module Chansey
  module Modules
    module Irc
      class Connection < EventMachine::Connection
        attr_reader :connected
        attr_accessor :handler

        def initialize(handler = lambda { })
          @handler = handler

          @inbound_pipeline = [
            LineDecoder.new,
            IrcDecoder.new,
          ]
        end

        def connection_completed
          @connected.succeed
        end

        def unbind
          @connected.fail
        end

        def receive_data(data)
          messages = []

          begin
            messages = parse(data)
          rescue => e
            close
          end

          messages.each do |msg|
            begin
              @handler.call(msg, self)
            rescue => e
            end
          end
        end

        # Override for logging and output pipeline
        def send_data(data)
          data += "\r\n"
          super(data)
        end

        private
        def parse(data)
          @inbound_pipeline.reduce([data]) do |objects, decoder|
            objects.flat_map { |o| decoder.map(o) }.compact
          end
        end
      end
    end
  end
end
