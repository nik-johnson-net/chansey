require 'eventmachine'

require 'chansey/irc_client/line_decoder'
require 'chansey/irc_client/irc_decoder'

module Chansey
  module IrcClient
    class Connection < EventMachine::Connection
      attr_reader :connected
      attr_accessor :handler

      def initialize(config, log, handler = lambda { })
        @config = config
        @connected = EventMachine::DefaultDeferrable.new
        @handler = handler
        @log = log

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
          @log.error "Exception parsing data: #{data}\n#{e}\n#{e.backtrace.join("\n")}"
        end

        messages.each do |msg|
          @log.debug "Received: #{msg}"
          begin
            @handler.call(msg, self)
          rescue => e
            @log.error "Exception raised calling handler: #{data}\n#{e}\n#{e.backtrace.join("\n")}"
          end
        end
      end

      # Override for logging and output pipeline
      def send_data(data)
        @log.debug "Sending: #{data}"

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
