#!/usr/bin/env ruby
require 'amqp'
require 'logger'
require 'json'
require 'fiber'
require_relative 'lib/plugin_wrapper.rb'
require_relative 'lib/plugin.rb'
require_relative 'lib/irc_plugin'

if ARGV.size != 1
   fail "Give a ruby plugin as the only argument"
end

EventMachine.run do 
    # Init logger
    log = Logger.new(STDOUT)
    log.level = Logger::DEBUG

    # Initialize the wrapper
    pw = Chansey::PluginWrapper.new(log)

    # Load and instantiate plugin
    pw.load ARGV[0]
end
