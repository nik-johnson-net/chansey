require_relative '../../common/service'
require_relative 'plugin'
require_relative 'interface'

# Mixins
require_relative 'irc_plugin'

module Chansey
    module Plugins
        class Controller < Common::Service
            PLUGIN_DIR = File.expand_path('../../plugins', __FILE__)

            def initialize(log, config, restart)
                super
                @interface = Plugins::Interface.new(log, @mq, @exchange)
                @plugins = {}

                @config['plugins'].each do |p|
                    # If its an alone filename, prepend with the plugin dir
                    p = File.join(PLUGIN_DIR, p) if File.basename(p) == p

                    load_plugin(p)
                end
            end

            def load_plugin(path)
                unless File.readable?(path)
                    @log.warn "Can not read plugin #{File.absolute_path(path)}"
                    return nil
                end

                name = File.basename(path).downcase
                if @plugins.key?(name)
                    @log.warn "A plugin with that name already exists"
                    return nil
                end

                # load
                plugin_module = Module.new

                begin
                  plugin_module.module_eval(File.read(path), path)
                rescue ScriptError => e
                  @log.warn("Plugin #{name} not loaded: #{e}")
                  return
                end

                plugin = Plugin.latest_plugin.new(@interface, @log, @config,
                                                  name, path)
                @plugins[name] = plugin
            end

            def reload_plugin(plugin)
                plugin_instance = @plugins[plugin.downcase]

                unless plugin_instance 
                    @log.warn "Can not reload plugin #{plugin}: plugin not loaded"
                    return "Plugin not loaded"
                end

                unload_plugin(plugin)
                load_plugin(plugin_instance.file_name)
            end

            def unload_plugin(plugin)
                plugin_instance = @plugins[plugin.downcase]

                unless plugin_instance 
                    @log.warn "Can not reload plugin #{plugin}: plugin not loaded"
                    return "Plugin not loaded"
                end

                # Plugin's callback
                plugin_instance.on_unload

                @interface.unload_plugin(plugin)
            end
        end
    end
end
