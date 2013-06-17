require_relative '../../plugin/lib/plugin_wrapper.rb'
require_relative 'plugin'
require 'sequel'

##
# Because the auth controller uses plugins, and the pluginwrapper is also based
# on a service, we can just base off of it.

module Chansey
    module Auth
        class Controller < Plugins::Controller
            DEFAULT_PLUGIN_DIR = File.expand_path('../../plugins', __FILE__)
            attr_reader :db
            def initialize(log, config, restart)
                @db = Sequel.connect(config['database'], :loggers => [log])
                @db.create_table? :users do
                    primary_key :id
                    String  :password_hash
                end

                config['plugin_directory'] ||= DEFAULT_PLUGIN_DIR

                puts config['plugin_directory']
                super
            end

            def load_plugin(file)
                file = super file, :db => @db
                @log.debug "Loadplugin: #{file}"
                @log.debug file.metadata
            end
        end
    end
end
