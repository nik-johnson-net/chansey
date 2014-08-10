require 'eventmachine'

require 'chansey/simple_router'

module Chansey
  class Core
    attr_reader :router

    def initialize(config, modules = [], router = SimpleRouter.new)
      @router = router
      @config = config
      @modules = modules
    end

    def run
      #TODO Don't call EM.run if already in loop
      EM.run do
        @modules.each do |m|
          EM.next_tick { m.post_init(self) }
        end
      end
    end
  end
end
