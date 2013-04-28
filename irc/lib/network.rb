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
        @nick_list = config['nick'].dup
        @server = nil
        @disconnect = false
    end

    def auto_connect?
        return @config['auto'] || false
    end

    def handle_lines(lines)
        lines.each do |line|
            @bot.log.debug "Network #{@config["name"]} received line: #{line}"

            case line[:command]
            when :ping
                pong(line[:params])
            when "433".to_sym
                # NICK collision
                @bot.log.warn "Nick collision on #{@name}"
                @nick_list.rotate!
                server_connected
            when "001".to_sym
                # Command to run on connect
                join(@config['channels'])
            end

            bot.create_event(@config["name"], line)
        end
    end

    def server_connected
        @bot.log.debug "Network #{@config["name"]} sending NICK and USER"

        nick(@nick_list.first)
        user(@nick_list.first, @config["fullname"])
    end

    def server_disconnected
        @bot.log.debug "Network #{@config["name"]} received server disconnect"
        @server = nil
        @bot.network_disconnected(self)

        # If we didn't want to disconnect (didn't send QUIT)
        # then reconnect.
        unless @disconnect
            @server_list.rotate!
            connect
            @disconnect = false
        end
    end

    def connect
        # Check if server list is empty
        if @server_list.size == 0
            @bot.log.warn "No server are listed for #{@name} to connect to"
            return nil
        end

        hostname = @server_list.first["hostname"]
        port = @server_list.first["port"]

        @bot.log.info "Connecting to #{hostname}:#{port}"
        @server = EM.connect(hostname, port, Chansey::IRC::Server, self)
    end
end
