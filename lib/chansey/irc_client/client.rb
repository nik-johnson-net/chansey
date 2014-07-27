require 'chansey/irc_client/command'
require 'chansey/irc_client/connection_monitor'

module Chansey
  module IrcClient
    class Client
      DEFAULT_IRC_PORT = 6667

      def initialize(config, router, log)
        @config = config
        @connections = {}
        @log = log
        @router = router

        @config['networks'].each { |k,v| connect(k) }

        @command_filters = [
          Command::NickPrefixedPrivmsgFilter.new,
          Command::StrPrefixedPrivmsgFilter.new(@config['command_prefix'] || "\0"),

          # Specify last as a Catch-All for private messages
          Command::DirectPrivmsgFilter.new
        ]
      end

      def connect(network)
        case x = @connections[network]
        when nil
          @log.debug("Starting connection attempt for #{network}")

          @connections[network] = ConnectionMonitor.new(network, @config['networks'].fetch(network), @log) do |msg, ctx|
            route(msg, ctx)
          end
        when x.class == ConnectionMonitor
          x
        end
      end

      private
      def detect_command(msg, ctx)
        # First filter to return a Command object wins
        @command_filters.reduce(nil) do |cmd_obj, filter|
          cmd_obj ||= filter.filter(msg, ctx)
        end
      end

      def route(msg, ctx)
        path = "irc/event/#{msg[:command]}"
        @router.route(path, msg, ctx)

        # Detect and route bot commands
        if cmd = detect_command(msg, ctx)
          path = "irc/command/#{cmd.command}"
          @router.route(path, cmd, ctx)
        end
      end
    end
  end
end
