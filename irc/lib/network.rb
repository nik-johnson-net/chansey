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
        @registered = false
        @current_nick = nil
        @disconnect = false
    end

    # Is this server set to autoconnect
    def auto_connect?
        return @config['auto'] || false
    end

    # Callback when the underlying server object receives a line
    def handle_lines(lines)
        lines.each do |line|
            @bot.log.debug "Network #{@config["name"]} received line: #{line}"

            case line[:command]
            when :ping
                pong(line[:params])

            when "433".to_sym
                if !@registered
                    # NICK collision on connect
                    @bot.log.warn "Nick collision on #{@name}"
                    @nick_list.rotate!
                    server_connected
                end

            when "001".to_sym
                # Command to run on connect
                @registered = true
                join(@config['channels'])

                # Start a periodic timer to change nick to the first choice
                if @current_nick != @config['nick'].first
                    @bot.log.info "Starting timer to attempt nick changes to first choice on #{@name}"

                    @timer = EventMachine::PeriodicTimer.new(300) do
                        nick(@config['nick'].first)
                    end
                end

            when :nick
                if line[:nick] == @current_nick
                    @current_nick = line[:params]
                    # Reset the nick_list if we changed to the first name 
                    if line[:params] == @config['nick'].first
                        @nick_list = @config['nick'].dup
                        if @timer
                            @bot.log.info "Nick change timer stopped due to successful nick change"
                            @timer.cancel
                        end
                    end
                end

            end

            bot.create_event(@config["name"], line)
        end
    end

    # Callback when the connection is established. IRC registration remains
    # false until 001 is received
    def server_connected
        @bot.log.debug "Network #{@config["name"]} sending NICK and USER"

        @current_nick = @nick_list.first
        nick(@nick_list.first)
        user(@nick_list.first, @config["fullname"])
    end

    # Callback for when the connection is closed. Checks are made for if a
    # reconnect is needed.
    def server_disconnected
        @registered = false
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

    # Command to start a connection
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
