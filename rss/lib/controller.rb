require 'amqp'
require 'json'
require_relative 'rssfetch'
require_relative '../../common/string'
require_relative '../../common/service'

module Chansey
    module RSS
        class Controller < Common::Service
            DEFAULT_TIMER = 300

            def initialize(log, config, restart)
                super
                @service_name = config['service_name']
                @period = config['timer'] || DEFAULT_TIMER
                @feeds = []

                @config['feeds'].each do |f|
                    @feeds << RSS::RSSFetch.new(self, f)
                end

                @timer = EventMachine::PeriodicTimer.new(@period, method(:on_timer))
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
