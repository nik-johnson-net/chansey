require 'eventmachine'

require 'chansey/modules/irc/line_decoder'
require 'chansey/modules/irc/irc_decoder'

module Chansey
  module Modules
    module Irc
      class Connection < EventMachine::Connection
        def initialize(handlers = [])
          if !handlers.is_a?(Enumerable)
            raise ArgumentError.new 'handlers is not an Enumerable'
          elsif !handlers.all?{ |h| h.respond_to? :call }
            raise ArgumentError.new 'Not all handlers respond to #call'
          end

          @handlers = handlers

          @inbound_pipeline = [
            LineDecoder.new,
            IrcDecoder.new,
          ]
        end

        def receive_data(data)
          messages = []

          begin
            messages = parse(data)
          rescue => e
            close
          end

          messages.each { |m| m.freeze }.freeze

          messages.each do |msg|
            @handlers.each do |h|
              begin
                h.call(msg, self)
              rescue => e
              end
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
