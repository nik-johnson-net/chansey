require 'logger'

module Chansey
  module Router
    class DefaultRouter
      DEFAULT_ROUTER_THRESHOLD = 50

      def initialize(log = Logger.new(nil))
        @globs = []
        @log = log
        @router = Hash.new { |h, k| h[k] = [] }
      end

      def register(*routes, &block)
        registration = RouterRegistration.new(self, routes, block)

        routes.each do |route|
          @router[route] << registration
        end

        registration
      end

      def unregister(router_registration)
        router_registration.routes.each do |route|
          @router[route].delete router_registration
        end

        # Garbage collect empty routes
        if @router.length > DEFAULT_ROUTER_THRESHOLD
          @router.delete_if do |k,v|
            v.length == 0
          end
        end

        nil
      end

      def route(route, *c_args)
        @router[route].each do |registration|
          begin
            registration.callback.call(*c_args)
          rescue => e
            @log.error "Exception calling registration: #{registration}: #{e}\n#{e.backtrace.join("\n")}"
          end
        end
      end

      def routes
        @router.keys
      end

      private
      class RouterRegistration
        attr_reader :routes
        attr_reader :callback

        def initialize(router, routes, callback)
          @routes = routes
          @router = router
          @callback = callback
        end

        def cancel
          @router.unregister self
        end
      end
    end
  end
end
