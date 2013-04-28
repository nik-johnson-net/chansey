#!/usr/bin/env ruby
require 'eventmachine'
require 'logger'
require 'yaml'
require 'trollop'

require_relative 'lib/bot'

def main(opts)
    log_file = opts[:logfile].empty? ? STDOUT : opts[:logfile]
    config_file = opts[:config].empty? ? File.expand_path("../config.yaml", __FILE__) : opts[:config]
    log = Logger.new(log_file)
    log.level = Logger::DEBUG
    config = YAML.load_file(config_file)

    EventMachine.run do
        bot = Chansey::IRC::Bot.new(log, config)
        trap "INT", &bot.method(:signal_int)
    end
end

opts = Trollop::options do
    opt :logfile, "Log file location", :short => "-l", :default => ""
    opt :config, "Config file location", :short => "-c", :default => File.expand_path("../config.yaml", __FILE__)
end

main opts
