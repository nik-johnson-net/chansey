require 'eventmachine'

require 'chansey/simple_router'

module Chansey
  # Core is the class which binds everything together.
  class Core
    attr_reader :router

    # Initializes the core components and optionally evaluates a block that
    # should return a list of instantiated modules.
    # @param config [Hash<String, String>] A list of parameters to fine tune behavior
    # @param router [#route] An object which handles routing
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

    # Adds a module to the Core
    # @param mod [Chansey::Module] The module to insert
    # @return the module
    def insert_module(mod)
      if !mod.is_a?(Module)
         raise ArgumentError.new "Module #{mod} did not inherit or include Chansey::Module"
      end

      @modules << mod

      mod
    end

    # Returns a list of modules
    # @return [Array<Chansey::Module>] modules
    def modules
      @modules.dup
    end

    # Starts running everything by calling #post_init on modules
    def run
      @modules.each do |m|
        EM.next_tick { m.post_init(self) }
      end

      nil
    end
  end
end
