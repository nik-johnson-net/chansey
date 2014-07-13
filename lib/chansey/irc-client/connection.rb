require 'eventmachine'

require 'chansey/irc-client/line_decoder'
require 'chansey/irc-client/irc_decoder'

module Chansey
  module IRC
    module Client
      class Connection < EventMachine::Connection
        attr_reader :connected

        def initialize
          @connected = EventMachine::DefaultDeferrable.new

          @inbound_pipeline = [
            LineDecoder.new,
            IrcDecoder.new,
          ]

          @receive_callbacks = []
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
            # TODO(njohnson) log it
          end

          messages.each do |msg|
            run_callbacks(msg)
          end
        end

        def on_message(&block)
          @receive_callbacks << block
        end

        private
        def parse(data)
          @inbound_pipeline.reduce([data]) do |objects, decoder|
            objects.flat_map { |o| decoder.map(o) }.compact
          end
        end

        def run_callbacks(data)
          @receive_callbacks.each do |cb|
            begin
              cb.call(data)
            rescue => e
              # TODO(njohnson) log it
            end
          end
        end
      end
    end
  end
end
