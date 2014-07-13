require 'eventmachine'

require 'chansey/irc-client/line_decoder'
require 'chansey/irc-client/irc_decoder'

module Chansey
  module IRC
    module Client
      class Connection < EventMachine::Connection

        def post_init
          @inbound_pipeline = [
            LineDecoder.new,
            IrcDecoder.new,
          ]
        end

        def receive_data(data)
          begin
            messages = parse(data)
          rescue => e
            # @bot.log.error "Parsing error: #{e.exception}: #{e.message}\nFor line: #{data}"
          else
            # Handle
          end
        end

        def parse(data)
          @inbound_pipeline.reduce([data]) do |objects, decoder|
            objects.flat_map { |o| decoder.map(o) }.compact
          end
        end
      end
    end
  end
end
