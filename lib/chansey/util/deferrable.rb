require 'eventmachine'

module Chansey
  module Util

    # Deferrable join is a conversion for a list of deferrables to wait on.
    class DeferrableJoin
      include EM::Deferrable

      FailedDeferrable = Struct.new(:args)
      SucceededDeferrable = Struct.new(:args)

      def initialize(*deferrables)
        if !deferrables.all? { |d| d.is_a? EM::Deferrable }
          raise ArgumentError, "All arguments must include EM::Deferrable"
        end

        @values = Array.new(deferrables.length)
        @deferrables = deferrables.each_with_index do |d, i|
          d.callback do |*args|
            @values[i] = SucceededDeferrable.new(args)

            if @values.all?
              succeed @values
            end
          end

          d.errback do |*args|
            @values[i] = FailedDeferrable.new(args)

            if @values.all?
              succeed @values
            end
          end
        end
      end

      # Complement to DeferrableJoin, this object succeeds on the first of the
      # list to complete.
      class DeferrableAny
        include EM::Deferrable

        def initialize(*deferrables)
          if !deferrables.all? { |d| d.is_a? EM::Deferrable }
            raise ArgumentError, "All arguments must include EM::Deferrable"
          end

          @completed = Array.new(deferrables.length, false)
          @deferrables = deferrables.each_with_index do |d, i|
            # On any success complete this with the args
            d.callback do |*args|
              succeed args
            end

            # Or, if all have failed then we should fail this object
            d.errback do |*args|
              @completed[i] = true

              if @completed.all?
                fail
              end
            end
          end
        end
      end
    end
  end
end
