require 'amqp'
require 'json'
require_relative 'rssfetch'
require_relative '../../common/string'
require_relative '../../common/event'

module Chansey
    module RSS
        class Controller
            DEFAULT_TIMER = 300

            attr_reader :log

            def initialize(log, config, restart)
                @service_name = 'rss'
                @log = log
                @config = config
                @restart = restart
                @egen = Common::EventGenerator.new(@service_name)
                @period = config['timer'] || DEFAULT_TIMER
                @feeds = []

                # Connect and instantiate AMQP Exchanges
                @amqp = AMQP.connect(:host => '127.0.0.1')
                @log.info "Connected to AMQP Broker"
                @mq = AMQP::Channel.new(@amqp)
                @exchange = @mq.topic("chansey")

                @config['feeds'].each do |f|
                    @feeds << RSS::RSSFetch.new(self, f)
                end

                @timer = EventMachine::PeriodicTimer.new(@period, method(:on_timer))
                on_timer
            end

            def on_timer
                @log.info "Fetching RSS Feeds..."
                @feeds.each { |f| f.fetch }
            end


            ##
            # This method is called by underlying network objects in order to move
            # events up the chain of command so that the bot may broadcast events
            # over the AMQP exchange.

            def create_event(msg)
                event = @egen.event('newitem', msg)
                route = "chansey.event.#{@service_name.amqp_safe}.#{event[:event].amqp_safe}"
                @exchange.publish(event.to_json, :routing_key => route)
                @log.debug "Pushed event to exchange: #{event}"
            end
        end # End Controller
    end # End RSS
end # End Chansey
