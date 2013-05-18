require_relative 'irc_senders'
require_relative 'server'

##
# The Network class represents an IRC Chatnet, or network. A Network object is
# the primary interface for sending IRC commands and handling responses. The
# underlying server connection is handled by the Server class, which is owned
# by a Network object. A Server object will only exist so long as the connection
# is open, but a Network object persists eternally. This gives the ability for
# multiple servers to be configured under a single network, and in the event a
# connection is lost to one the bot can reconnect to another server on the same
# network.

class Chansey::IRC::Network
    include Chansey::IRC::IRC_Senders

    ##
    # The bot name
    attr_reader :bot

    ##
    # The underlying Server class, or nil if not connected.
    attr_reader :server

    ##
    # The name of the network
    attr_reader :name


    ##
    # The +bot+ argument should be the instance of the Bot class which owns
    # this network. The +config+ variable should contain a Hash of options
    # for this particular network.
    
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


    ##
    # This function will return the value of the network's 'auto' configuration
    # value, which specifies whether or not the server should connect when
    # the bot is started.

    def auto_connect?
        return @config['auto'] || false
    end

    
    ##
    # This function is a callback for the instantiated server object. It is
    # called when the server has parsed IRC lines into a hash and is ready
    # for processing. +lines+ is an array, since it's possible for multiple
    # lines to be received at once.

    def handle_lines(lines)
        lines.each do |line|
            @bot.log.debug "Network #{@config["name"]} received line: #{line}"

            # Convert the name into a function name and call the response if
            # funtion is defined
            method_name = "on_#{line[:command]}"
            method(method_name).call(line) if respond_to?(method_name, true)

            # Pass the message up to the bot for forwarding to AMQP
            bot.create_event(@config["name"], line)
        end
    end


    ##
    # Callback when the connection is established. IRC registration remains
    # false until 001 is received

    def server_connected
        @bot.log.debug "Network #{@config["name"]} sending NICK and USER"

        @current_nick = @nick_list.first
        nick(@nick_list.first)
        user(@nick_list.first, @config["fullname"])
    end

    
    ##
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


    ##
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

    private


    ##
    # Responds to pings

    def on_ping(message)
        pong( message[:params] )
    end

    
    ##
    # Responds to NICK COLLISION errors

    def on_433(message)
        if !@registered
            # NICK collision on connect
            @bot.log.warn "Nick collision on #{@name}"
            @nick_list.rotate!
            server_connected
        end
    end


    ##
    # Responds to WELCOME messages

    def on_001(message)
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
    end


    ##
    # Responds to NICK commands

    def on_nick(message)
        if message[:nick] == @current_nick
            @current_nick = message[:params]
            # Reset the nick_list if we changed to the first name 
            if message[:params] == @config['nick'].first
                @nick_list = @config['nick'].dup
                if @timer
                    @bot.log.info "Nick change timer stopped due to successful nick change"
                    @timer.cancel
                end
            end
        end
    end
end
