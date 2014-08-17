require 'eventmachine'

require 'chansey/modules/irc/line_decoder'
require 'chansey/modules/irc/irc_decoder'
require 'chansey/modules/irc/handler'

module Chansey
  module Modules
    module Irc
      class Connection < EventMachine::Connection

        def initialize(handlers = [])
          if !handlers.is_a?(Enumerable)
            raise ArgumentError.new 'handlers is not an Enumerable'
          elsif !handlers.all?{ |h| h.is_a? Irc::Handler }
            raise ArgumentError.new 'Not all handlers include Irc::Handler'
          end

          @handlers = handlers
          @registered = false

          @inbound_pipeline = [
            LineDecoder.new,
            IrcDecoder.new,
          ]
        end

        def registered?
          @registered
        end

        def unbind
          @handlers.each do |h|
            h.disconnected(self)
          end
        end

        def receive_data(data)
          messages = parse(data)
          messages.each { |m| m.freeze }.freeze

          messages.each do |msg|
            detect_registration

            @handlers.each do |h|
              h.receive_message(msg, self)
            end
          end
        end

        # Override for logging and output pipeline
        def send_data(data)
          data += "\r\n"
          super(data)
        end

        private
        def detect_registration(message)
          if !registered? && ![:notice, :error].include?(message[:command])
            @registered = true

            @handlers.each do |h|
              h.registered(self)
            end
          end

          nil
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
