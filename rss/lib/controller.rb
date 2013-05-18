require 'amqp'
require 'json'
require_relative 'rssfetch'

##
# Adds a function to the String class to convert a string to a form which is
# safe to be used in AMQP routing keys.
#
# Stolen from mokomull and his Erlang bot.
# 
# Source: http://git.mmlx.us/?p=erlbot.git;a=blob;f=irc/irc_amqp_listener.erl

class String
    def amqp_safe
        str = ""
        each_char do |c|
            case c
            when /[0-9a-z]/
                str += c
            when /[A-Z]/
                str += "C#{c.downcase}"
            else
                str += "X#{c.unpack('C')[0].to_s(16).upcase}"
            end
        end

        return str
    end
end

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
                @period = config['timer'] || DEFAULT_TIMER
                @feeds = []

                # Connect and instantiate AMQP Exchanges
                @amqp = AMQP.connect(:host => '127.0.0.1')
                @log.info "Connected to AMQP Broker"
                @mq = AMQP::Channel.new(@amqp)
                @exchange = @mq.topic("chansey")

                # Declare variable to track IDs
                @last_timestamp = {
                    :timestamp => Time.now.to_i,
                    :counter => 0
                }

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
                    :event => 'newitem',
                    :data => msg
                }
                @exchange.publish(event.to_json,
                                  :routing_key => "chansey.event.#{@service_name.amqp_safe}.#{event[:event].amqp_safe}")
                @log.debug "Pushed event to exchange: #{event}"
            end
        end # End Controller
    end # End RSS
end # End Chansey
