module Chansey
  module IrcClient
    class IrcDecoder
      # Magic regex to parse IRC according to RFC 2812
      PARSE_REGEX = /^(?>:([^! ]+)(?:(?:!([^!@ ]+))?@([^@! ]+))? )?(\w+)((?: (?![:])(?:\S)+){0,14})(?: :(.*))?$/

      def map(line)
        # Parse into regex matche
        match = line.rstrip.match(PARSE_REGEX)

        if match
          # Map into hash structure
          {
            :nick     => match[1],
            :user     => match[2],
            :host     => match[3],
            :command  => match[4].downcase.to_sym,
            :middle   => match[5].split,
            :trailing => match[6]
          }
        else
          nil
        end
      end
    end
  end
end
