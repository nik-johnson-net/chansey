require 'amqp'
require 'json'
require_relative 'network'
require_relative 'rpc_handler'

##
# This class represents the Bot as a whole. It inherits all responsibility for
# everything that is outside the scope of a single IRC Network. As well as
# directing networks, the class handles signals, the AMQP queues, and RPC
# requests.

module Chansey
    module IRC
        class Bot
            attr_reader :log
            attr_reader :config
            attr_reader :exchange
            attr_reader :service_name
            attr_reader :networks

            ##
            # Upon instantiation, the class will connect to AMQP and establish its
            # queue. Each network is also instantiated here and given its configuration
            # and told to connect if specified with the auto flag.

            def initialize(logger, config, restart=nil)
                @service_name = "irc"
                @quit = false
                @log = logger
                @restart = restart
                @config = config
                @networks = {}

                # Connect and instantiate AMQP Exchanges
                @amqp = AMQP.connect(:host => '127.0.0.1')
                @log.info "Connected to AMQP Broker"
                @mq = AMQP::Channel.new(@amqp)
                @exchange = @mq.topic("chansey")

                # Create service queue
                @rpc_handler = IRC::RPCHandler.new(@log, @service_name, @mq, @exchange, self)

                # Create network instances
                @log.debug "Bot initializing, creating networks"
                @config["networks"].each do |config|
                    @networks[config["name"]] = IRC::Network.new(self, config)
                end

                # Connect to the autoload networks
                @log.debug "Bot initializing, connecting to networks"
                @networks.each do |n,v|
                    v.connect if v.auto_connect?
                end

                # Declare variable to track IDs
                @last_timestamp = {
                    :timestamp => Time.now.to_i,
                    :counter => 0
                }
            end


            ##
            # This method is called by underlying network objects in order to move
            # events up the chain of command so that the bot may broadcast events
            # over the AMQP exchange.

            def create_event(network, msg)
                timestamp = Time.now.to_i
                if timestamp == @last_timestamp[:timestamp]
                    @last_timestamp[:counter] += 1
                else
                    @last_timestamp[:timestamp] = timestamp
                    @last_timestamp[:counter] = 0
                end
                id = "%d%d%06d" % [ Process.pid, timestamp, @last_timestamp[:counter] ]

                event = {
                    :type => "event",
                    :timestamp => Time.now.to_i,
                    :id => id,
                    :service => @service_name.amqp_safe,
                    :event => msg[:command],
                    :data => {
                    :network => "#{network}",
                    :msg     => msg
                }
                }
                @exchange.publish(event.to_json,
                                  :routing_key => "chansey.event.#{@service_name.amqp_safe}.#{msg[:command].to_s.amqp_safe}")
                @log.debug "Pushed event to exchange: #{event}"
            end


            ##
            # This method is called by underlying network objects when one becomes
            # disconnected. Right now its only purpose is to detect the quit condition
            # for the EventMachine loop.

            def network_disconnected(net)
                if @quit and @networks.values.all? { |n| n.server.nil? }
                    @log.info "Quit wanted and all networks are disconnected. Stopping event loop..."
                    EM.stop_event_loop
                end
            end


            ##
            # Restarts the bot, sending reason to all servers

            def restart(reason="Restarting IRC Module")
                @log.info "Restarting bot..."

                @quit = true
                @networks.each do |k,v|
                    v.quit(reason)
                end
            end


            ##
            # Stops the bot, sending reason to all servers

            def stop(reason="Stopping IRC Module")
                @log.info "Stopping bot..."

                @quit = true
                @restart.restart = false if @restart
                @networks.each do |k,v|
                    v.quit(reason)
                end
            end

            private

            ##
            # The SIGINT handler. Sends QUIT to all networks.

            def signal_int(*args)
                @log.info "Caught SIGINT"

                stop("Caught SIGINT")
            end
        end
    end
end
