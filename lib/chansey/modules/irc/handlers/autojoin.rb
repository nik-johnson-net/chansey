require 'chansey/modules/irc/handler'

module Chansey
  module Modules
    module Irc
      module Handlers
        class Autojoin
          include Irc::Handler

          JOIN = 'JOIN %s'

          def initialize(autojoin_channels)
            if !autojoin_channels.is_a? Array
              raise TypeError.new "Expected an Array"
            elsif !autojoin_channels.all?{ |c| c.is_a? String }
              raise TypeError.new "Expected an Array of Strings"
            end

            @channels = autojoin_channels
          end

          def registered(connection)
            @channels.each_slice(10) do |slice|
              connection.send_data(JOIN % slice.join(','))
            end
          end
        end
      end
    end
  end
end
