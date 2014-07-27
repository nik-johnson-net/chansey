module Chansey
  class PluginHost
    BUNDLED_PLUGIN_PATH = Dir.new(File.expand_path('../../../plugins', __FILE__))

    class Plugin
      def initialize(path, log, mod_factory)
        @path = path
        @loaded = false
        @log = log
        @mod_factory = mod_factory
        @module = nil
      end

      def load
        if !@loaded
          @log.info "Loading plugin #{@path}"

          begin
            try_load
            @loaded = true
          rescue ScriptError, StandardError => e
            @log.warn "Could not load plugin #{@path}: #{e}\n#{e.backtrace.join("\n")}"
          end
        end

        @loaded
      end

      private
      def try_load
        contents = File.read(@path)
        @module = @mod_factory.call(contents, @path)
      end
    end

    def initialize(services, router, config, log)
      @config = config
      @log = log
      @router = router
      @services = services.dup.freeze
      @mod_factory = lambda do |contents, path=""|
        new_mod = Module.new
        new_mod.instance_exec(@router, @services) do |rtr, srv|
          @router = rtr
          @services = srv
        end
        new_mod.instance_eval(contents, path)
      end

      # Turns plugin paths into Dir objects and append the default path
      @plugin_paths = config.fetch('plugin_paths', []).
        map { |pp| Dir.new pp }.
        push(BUNDLED_PLUGIN_PATH)

      # Iterate through plugins configured to autoload and find them.
      @plugins = @config.fetch('plugins', []).
        map { |p| search_for_plugin(p) }.
        compact.
        map { |p| Plugin.new(p, @log, @mod_factory) }

      # Load all plugins
      @plugins.each { |p| p.load }
    end

    private
    def search_for_plugin(plugin_file)
      path = @plugin_paths.flat_map do |dir|
        dir.map { |f| File.expand_path(f, dir.path) }.
          select { |f| File.file?(f) }
      end.find { |f| File.basename(f, '.rb') == File.basename(plugin_file, '.rb') }

      if !path
        @log.warn "Could not find plugin: #{plugin_file}"
      end

      path
    end
  end
end
