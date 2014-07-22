module Chansey
  module IrcClient
    class LineDecoder
      def initialize
        @buffer = ""
      end

      def map(data)
        if data.class != String
          raise ArgumentError
        end

        lines = []

        while true
          line, sep, data = data.partition(/\r?\n/)

          if sep.empty?
            @buffer += line
            break
          end

          if !@buffer.empty?
            line.prepend @buffer
            @buffer = ""
          end

          lines << line
        end

        lines
      end
    end
  end
end
