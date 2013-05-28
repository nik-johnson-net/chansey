##
# Adds a function to the String class to convert a string to a form which is
# safe to be used in AMQP routing keys.
#
# Stolen from mokomull and his Erlang bot.
# 
# Source: http://git.mmlx.us/?p=erlbot.git;a=blob;f=irc/irc_amqp_listener.erl

class String
    def amqp_safe
        str = ""
        each_char do |c|
            case c
            when /[0-9a-z]/
                str += c
            when /[A-Z]/
                str += "C#{c.downcase}"
            else
                str += "X#{c.unpack('C')[0].to_s(16).upcase}"
            end
        end

        return str
    end
end
