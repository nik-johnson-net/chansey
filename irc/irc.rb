#!/usr/bin/env ruby
# :nodoc: all
require 'eventmachine'
require 'logger'
require 'yaml'
require 'trollop'

require_relative 'lib/bot'
require_relative '../common/service'


def main(opts)
    # Set logging to be STDOUT if the log option is not specified
    log_file = opts[:logfile].empty? ? STDOUT : opts[:logfile]

    # Set the config file to default to 'config.yaml' in the same directory as this file
    config_file = opts[:config].empty? ? File.expand_path("../config.yaml", __FILE__) : opts[:config]

    # Start the logger and set the level
    log = Logger.new(log_file)
    log.level = Logger::DEBUG

    # Control whether to restart the bot upon a shutdown sequence or just quit
    restart = Chansey::Common::RestartToggleClass.new

    while restart.restart
        # Load the configuration file
        config = YAML.load_file(config_file)

        begin
            EventMachine.run do
                bot = Chansey::IRC::Bot.new(log, config, restart)

                # Signal traps callback to the bot for clean shutdowns and other
                # interactions.
                trap "INT", &bot.method(:signal_int)
            end
        rescue => e
            log.fatal "FATAL Uncaught exception: #{e.exception}: #{e.message}\n#{e.backtrace.join("\n")}"
        end
    end
end

opts = Trollop::options do
    opt :logfile, "Log file location", :short => "-l", :default => ""
    opt :config, "Config file location", :short => "-c", :default => File.expand_path("../config.yaml", __FILE__)
end

main opts
