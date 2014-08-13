module Chansey
  class Module
    def initialize(core)
      @core = core
    end

    def post_init
    end

    def pre_shutdown
    end

    def route(route, *args)
      @core.router.route(path, *args)
    end

    def register(route, &block)
      @core.router.register(route, &block)
    end
  end
end
