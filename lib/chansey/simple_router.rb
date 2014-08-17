module Chansey
  # SimpeRouter is a Router which does some simple garbage collection
  class SimpleRouter
    DEFAULT_ROUTER_THRESHOLD = 100

    def initialize
      @router = Hash.new { |h, k| h[k] = [] }
    end

    def register(route, &block)
      registration = RouterRegistration.new(self, route, block)
      @router[route] << registration

      optional_garbage_collect_routes

      registration
    end

    def unregister(router_registration)
      @router[router_registration.route].delete router_registration

      optional_garbage_collect_routes

      nil
    end

    def route(path, arg)
      @router[path].each do |registration|
        registration.call(arg)
      end
    end

    def routes
      @router.keys
    end

    private
    # Represents a registered route to clients so they can easily cancel the
    # registration
    class RouterRegistration
      attr_reader :route
      attr_reader :callback

      def initialize(router, route, callback)
        @route = route
        @router = router
        @callback = callback
      end

      def call(arg)
        begin
          @callback.call(arg)
        rescue => e
        end
      end

      def cancel
        @router.unregister self
      end
    end

    def optional_garbage_collect_routes
      if @router.length > DEFAULT_ROUTER_THRESHOLD
        garbage_collect_routes
      end
    end

    def garbage_collect_routes
      @router.delete_if do |k,v|
        v.length == 0
      end
    end
  end
end
