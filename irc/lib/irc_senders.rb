module Chansey
    module IRC
        ##
        # The IRC Senders module is a mixin for adding convenience functions to
        # network objects. The functions wrap the semantics of IRC commands
        # with easy to use function calls. Well, except for the mode command.

        module IRC_Senders

            ##
            # Sends just a raw message to the server. Simply appends the content with \r\n

            def raw(content)
                @server.send_data("#{content}\r\n")
                @bot.log.debug "Sending to #{@server}: #{content.inspect}"
            end


            ##
            # Sends a NICK message

            def nick(nick)
                raw("NICK #{nick}")
            end


            ##
            # Sends a USER message. The usermode defaults to invisible

            def user(nick, fullname, usermode=8)
                raw("USER #{nick} #{usermode} * :#{fullname}")
            end


            ##
            # Sends a PING message

            def ping(identifier)
                raw("PING :#{identifier}")
            end

            ##
            # Sends a PONG message

            def pong(data)
                raw("PONG :#{data}")
            end


            ##
            # Sends a JOIN command. Channels and keys may be arrays or a string.
            # No real semantic checking is done to ensure compliance with the RFC.

            def join(channels, keys='')
                channels = to_array(channels)
                keys = to_array(keys)

                msg = "JOIN #{channels.join(',')}"
                msg += " #{keys.join(',')}" if keys.length > 0
                raw(msg)
            end


            ##
            # Sends a part command with an optional part message. May take an
            # array of channels or a string.

            def part(channels, msg=nil)
                channels = to_array(channels)
                msg = "PART #{channels.join(',')}"
                msg += " :#{msg}" unless msg.nil?
                raw(msg)
            end


            ##
            # Sends a MODE command. I'd recommend just reading the RFC on the
            # mode command; it's a cluster cuss.

            def mode(channel, modes, operands=nil)
                operands = to_array(operands) if operands
                msg = "MODE #{channel} #{modes}"
                msg += " #{operands.join(' ')}" if operands
                raw(msg)
            end


            ##
            # Sends a TOPIC command, optionally specifying a new topic.
            # A nil topic is allowable and returns the current topic,

            def topic(channel, topic=nil)
                msg = "TOPIC #{channel}"
                msg += " :#{topic}" if topic
                raw(msg)
            end


            ##
            # The INVITE command invites +nick+ to +channel+

            def invite(nick, channel)
                raw("INVITE #{nick} #{channel}")
            end


            ##
            # Sends a KICK command with an optional kick message. +channels+ and
            # +users+ may be an array.

            def kick(channels, users, comment=nil)
                channels = to_array(channels)
                users = to_array(users)
                msg = "KICK #{channels.join(',')} #{users.join(',')}"
                msg += " :#{comment}" if comment
                raw(msg)
            end


            ##
            # Sends a PRIVMSG to the server. +channel+ can be either a channel
            # name or a nick.

            def privmsg(channel, msg)
                raw("PRIVMSG #{channel} :#{msg}")
            end


            ##
            # Same as privmsg, but sends a NOTICE

            def notice(channel, msg)
                raw("NOTICE #{channel} :#{msg}")
            end


            ##
            # Sends a QUIT message. This is currently the only way to disconnect
            # from a server and not trigger an auto-reconnect.

            def quit(msg)
                @disconnect = true
                raw("QUIT :#{msg}")
            end

            private
            def to_array(parameter)
                if parameter.class == String
                    if parameter.empty?
                        parameter = []
                    else
                        parameter = [parameter]
                    end
                elsif parameter.class != Array
                    raise ArgumentError
                end
                parameter
            end
        end
    end
end
