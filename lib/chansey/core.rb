require 'chansey/simple_router'

module Chansey
  class Core
    attr_reader :router

    def initialize(config, modules = [], router = SimpleRouter.new)
      @router = router
      @config = config
      @modules = modules
    end
  end
end
