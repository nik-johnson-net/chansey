require 'eventmachine'

require 'chansey/simple_router'

module Chansey
  class Core
    attr_reader :router

    def initialize(config, router = SimpleRouter.new)
      @router = router
      @config = config
      @modules = []

     if block_given?
       mods = yield self

       if !mods.is_a?(Enumerable)
         raise ArgumentError.new "Constructor block did not yield an Enumerable"
       end

       mods.each { |m| insert_module(m) }
     end
    end

    def insert_module(mod)
      if !mod.is_a?(Module)
         raise ArgumentError.new "Module #{mod} did not inherit or include Chansey::Module"
      end

      mod.post_init
      @modules << mod

      mod
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
