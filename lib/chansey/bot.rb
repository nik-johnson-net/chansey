require 'chansey/router/router'
require 'chansey/irc_client/client'
require 'chansey/plugin_host'

module Chansey
  class Bot
    def initialize(config, log)
      @router = Router.new(log)
      services = {}
      services[:irc] = IrcClient::Client.new(config['irc'], @router, log)

      @plugin_host = PluginHost.new(services, @router, config['plugins'], log)
    end
  end
end
