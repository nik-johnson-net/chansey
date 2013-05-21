#!/usr/bin/env ruby
require 'amqp'
require 'logger'
require 'json'
require 'fiber'
require 'trollop'
require_relative 'lib/plugin_wrapper.rb'
require_relative 'lib/plugin.rb'
require_relative 'lib/irc_plugin'

opts = Trollop::options do
    opt :logfile, "Log file location", :short => "-l", :default => ""
end

Trollop::die "No plugin specified" if ARGV.empty?

begin
    EventMachine.run do 
        # Init logger
        log_file = opts[:logfile].empty? ? STDOUT : opts[:logfile]
        log = Logger.new(log_file)
        log.level = Logger::DEBUG

        # Initialize the wrapper
        pw = Chansey::PluginWrapper.new(log)

        # Load and instantiate plugin
        pw.load ARGV[0]
    end
rescue => e
    log.fatal "FATAL Uncaught exception: #{e.exception}: #{e.message}\n#{e.backtrace.join("\n")}"
end
