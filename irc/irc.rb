#!/usr/bin/env ruby
require 'eventmachine'
require 'logger'
require 'yaml'

require_relative 'lib/bot'

def main
    log = Logger.new(STDOUT)
    log.level = Logger::DEBUG
    config = YAML.load_file('config.yaml')

    EventMachine.run do
        bot = Chansey::IRC::Bot.new(log, config)
        trap "INT", &bot.method(:signal_int)
    end
end

main
