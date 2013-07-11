# encoding: utf-8

require 'eventmachine'
require 'json'
require 'amqp'
require 'yaml'
require_relative '../../common/event'
require_relative '../../common/hash'
require_relative '../../common/string'

class IRCAMQP

    def initialize(config, &block)
        @config = config
        @service_name = config['service_name']
        connect_to_amqp

        @idgen = Chansey::Common::EventIdGenerator.new
        @queue = @channel.queue('', :auto_delete => true)
        @queue.bind(@exchange, :routing_key => "chansey.event.irc.#")
        @queue.subscribe(&block)
    end

    def connect_to_amqp
        unless @config['amqp'] and @config['amqp']['exchange']
            raise KeyError, 'config file must define \'exchange\' under \'amqp\''
        end

        amqp_opts = @config['amqp'].keys_to_sym

        @amqp = AMQP.connect(amqp_opts)

        @channel = AMQP::Channel.new(@amqp)
        @exchange = @channel.topic(amqp_opts[:exchange])
    end

    def send(network, line)
        id = @idgen.new_id

        opts = {
            :network => "#{network}",
            :line => line
        }

        payload = {
            :type => 'cmd',
            :timestamp => Time.now.to_i,
            :id => id,
            :command => 'raw',
            :origin => 'irc-cli',
            :opts => opts
        }
        route = "chansey.service.#{@service_name.amqp_safe}"

        @exchange.publish(payload.to_json, :routing_key => route)
    end
end

module KeyboardHandler
    def initialize(sender)
        @buffer = ""
        @sender = sender
    end

    def receive_data(char)
        if char == "\n"
            puts "Sending #{@buffer}"
            @sender.call(@buffer)
            @buffer = ""
        else
            @buffer += char
        end
    end
end

def main(network)
    config_file = File.expand_path("../../config.yaml", __FILE__)
    config = YAML.load_file(config_file)
    EM.run do 
        conn = IRCAMQP.new(config) do |event|
            event = JSON.parse(event)
            puts event['data']['msg'] if event['data']['network'] == network
        end

        EM.open_keyboard(KeyboardHandler, lambda do |line|
            conn.send(network, line)
        end)

        puts "Connected to Message Queue"
    end
end

if ARGV.empty?
    puts "Usage: #{$0} <network>"
else
    puts "Connecting to speak on network #{ARGV[0]}"
    main(ARGV[0])
end
