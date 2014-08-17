module Chansey
  class Module
    def initialize(core)
      @core = core
    end

    def post_init
    end

    def pre_shutdown
    end

    def route(route, arg)
      @core.router.route(path, arg)
    end

    def register(route, &block)
      @core.router.register(route, &block)
    end
  end
end
