module Chansey
    module Common


        ##
        # This is such a hack....
        # Gives a controlling class an easy way to signal the main method
        # that a fail-restart loop should continue.

        class RestartToggleClass
            attr_accessor :restart

            def initialize
                @restart = true
            end
        end
    end
end
