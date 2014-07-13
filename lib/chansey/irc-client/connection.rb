require 'eventmachine'

require 'chansey/irc-client/line_decoder'
require 'chansey/irc-client/irc_decoder'

module Chansey
  module IRC
    module Client
      class Connection < EventMachine::Connection
        def initialize
          @connected = :connecting

          @inbound_pipeline = [
            LineDecoder.new,
            IrcDecoder.new,
          ]

          @receive_callbacks = []
        end

        def notify_on_connect(deferrable)
          case @connected
          when :connecting
            @on_connects ||= []
            @on_connects << deferrable
          when :connected
            deferrable.succeed
          when :disconnected
            deferrable.fail "Already disconnected"
          end
          end
        end

        def connection_completed
          @connected = :connected
        end

        def unbind
          @connected = :disconnected
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
          @callbacks.each do |cb|
            begin
              cb.call(msg)
            rescue => e
              # TODO(njohnson) log it
            end
          end
        end
      end
    end
  end
end
