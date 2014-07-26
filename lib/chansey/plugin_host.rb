module Chansey
  class PluginHost
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
          begin
            try_load
            @loaded = true
          rescue => e
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

      @plugins = config['plugins'].map { |p| Plugin.new(p, log, @mod_factory) }

      @plugins.each { |p| p.load }
    end
  end
end
