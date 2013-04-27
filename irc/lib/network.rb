require_relative 'irc_senders'
require_relative 'server'

class Chansey::IRC::Network
    include Chansey::IRC::IRC_Senders

    attr_reader :bot
    attr_reader :server
    attr_reader :name

    def initialize(bot, config)
        @name = config["name"]
        @bot = bot
        @config = config
        @server_list = config["servers"].dup
        @server = nil
    end

    def handle_lines(lines)
        lines.each do |line|
            @bot.log.debug "Network #{@config["name"]} received line: #{line}"

            pong(line[:params]) if line[:command] == :ping

            bot.create_event(@config["name"], line)
        end
    end

    def server_connected
        @bot.log.debug "Network #{@config["name"]} sending NICK and USER"

        nick(@config["nick"])
        user(@config["nick"], @config["fullname"])
    end

    def server_disconnected
        @bot.log.debug "Network #{@config["name"]} received server disconnect"
        @server = nil
        @bot.network_disconnected(self)
    end

    def connect
        hostname = @server_list.first["hostname"]
        port = @server_list.first["port"]

        @bot.log.info "Connecting to #{hostname}:#{port}"
        @server = EM.connect(hostname, port, Chansey::IRC::Server, self)
    end
end
