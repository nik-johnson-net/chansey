require 'amqp'
require 'json'
require_relative 'network'
require_relative 'requests'

class Chansey::IRC::Bot
    include Chansey::IRC::Requests

    attr_reader :log
    attr_reader :config
    attr_reader :exchange
    attr_reader :service_name

    def initialize(logger, config)
        @service_name = "irc"
        @quit = false
        @log = logger
        @config = config
        @networks = {}

        # Connect and instantiate AMQP Exchanges
        @amqp = AMQP.connect(:host => '127.0.0.1')
        @log.info "Connected to AMQP Broker"
        @mq = AMQP::Channel.new(@amqp)
        @exchange = @mq.topic("chansey")

        # Create service queue
        @queue = @mq.queue('', :auto_delete => true)
        @queue.bind(@exchange, :routing_key => "chansey.service.#{@service_name.amqp_safe}")
        puts @exchange, "chansey.service.#{@service_name.amqp_safe}"
        @queue.subscribe(&method(:rpc_handler))

        # Create network instances
        @log.debug "Bot initializing, creating networks"
        @config["networks"].each do |config|
            @networks[config["name"]] = Chansey::IRC::Network.new(self, config)
        end

        # Connect to the autoload networks
        @log.debug "Bot initializing, connecting networks"
        @networks.each do |n,v|
            v.connect
        end

        # Declare variable to track IDs
        @last_timestamp = {
            :timestamp => Time.now.to_i,
            :counter => 0
        }
    end

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

    def network_disconnected(net)
        if @quit and @networks.values.all? { |n| n.server.nil? }
            @log.info "Quit wanted and all networks are disconnected. Stopping event loop..."
            EM.stop_event_loop
        end
    end

    private
    def rpc_handler(metadata, payload)
        @log.debug "Received command: #{payload}"

        begin
            payload = JSON.parse(payload)
            req = Chansey::IRC::Request.new(@exchange, metadata, payload)
            route_request(req)
        rescue => e
            @log.warn "Received bad message and threw #{e.exception}\n#{e.backtrace.join("\n")}"
            return
        end

    end

    def signal_int(*args)
        @quit = true
        @networks.each do |k,v|
            v.quit("Caught SIGINT")
        end
    end
end
