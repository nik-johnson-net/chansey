require_relative '../../common/service'

module Chansey
    module Plugins
        class Controller < Common::Service
            PLUGIN_DIR = 'plugins'

            def initialize(*args)
                super
                @interface = Plugins::Interface.new
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

                # load
                plugin
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
            end
        end
    end
end
