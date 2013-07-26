require 'amqp'
require 'json'
require_relative 'network'
require_relative 'rpc_callbacks'
require_relative '../../common/service'

##
# This class represents the Bot as a whole. It inherits all responsibility for
# everything that is outside the scope of a single IRC Network. As well as
# directing networks, the class handles signals, the AMQP queues, and RPC
# requests.

module Chansey
    module IRC
        class Bot < Common::Service
            attr_reader :config
            attr_reader :exchange
            attr_reader :networks

            ##
            # Upon instantiation, the class will connect to AMQP and establish its
            # queue. Each network is also instantiated here and given its configuration
            # and told to connect if specified with the auto flag.

            def initialize(logger, config, restart=nil)
                super
                @rpc_handler.extend(IRC::RemoteProcedures)
                @service_name = config['service_name']
                @quit = false
                @networks = {}

                # Create network instances
                @log.debug "Bot initializing, creating networks"
                @config["networks"].each do |config|
                    if !new_network(config)
                        @log.warn "Attempted to create a network that already exists (#{config['name']})"
                    end
                end

                # Connect to the autoload networks
                @log.debug "Bot initializing, connecting to networks"
                @networks.each do |n,v|
                    v.connect if v.auto_connect?
                end


                # Periodic timer for trapping signals
                EM.add_periodic_timer(2) do
                    case @trapped_signal

                    # SIGTERM, SIGINT
                    when 2, 15
                        stop("Quitting by system signal.")

                    # SIGHUP
                    when 1
                        restart("Restarting by SIGHUP.")
                    end
                end
            end


            def new_network(config)
                if @networks.key? config['name']
                    return false
                else
                    @networks[config['name']] = IRC::Network.new(self, config)
                    return true
                end
            end
            ##
            # This method is called by underlying network objects in order to move
            # events up the chain of command so that the bot may broadcast events
            # over the AMQP exchange.

            def create_event(network, msg)
                data = {
                    :network => "#{network}",
                    :msg     => msg
                }
                event = @egen.event(msg[:command], data)
                route = "chansey.event.#{@service_name.amqp_safe}.#{msg[:command].to_s.amqp_safe}"

                @exchange.publish(event.to_json, :routing_key => route)
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
                    v.quit(reason) if v.server
                end
            end


            ##
            # Stops the bot, sending reason to all servers

            def stop(reason="Stopping IRC Module")
                @log.info "Stopping bot..."

                @quit = true
                @restart.restart = false if @restart
                @networks.each do |k,v|
                    v.quit(reason) if v.server
                end
            end

            private


            ##
            # The SIGINT handler. Sends QUIT to all networks.

            def signal_trap(signo)
                @trapped_signal = signo
            end
        end
    end
end
