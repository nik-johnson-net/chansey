require 'chansey/router/default_router'

module Chansey
  module Router
    class << self
      def new(*args)
        DefaultRouter.new(*args)
      end
    end
  end
end
