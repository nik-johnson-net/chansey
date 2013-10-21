require 'json'
require 'amqp'
require_relative '../common/event'

EM.run do
    amqp = AMQP.connect
    channel = AMQP::Channel.new(amqp)
    exchange = channel.topic('chansey')

    eventgen = Chansey::Common::EventGenerator.new(ARGV[0])
    input = JSON.parse(STDIN.read)

    event = eventgen.event(ARGV[1], input)
    exchange.publish(event.to_json, :routing_key => "chansey.event.#{ARGV[0]}.#{ARGV[1]}")

    EM.add_timer(1) { EM.stop }
end
