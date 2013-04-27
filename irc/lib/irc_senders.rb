module Chansey
    module IRC
        module IRC_Senders
            def raw(content)
                @server.send_data("#{content}\r\n")
                @bot.log.debug "Sending to #{@server}: #{content.inspect}"
            end

            def nick(nick)
                raw("NICK #{nick}")
            end

            def user(nick, fullname, usermode=8)
                raw("USER #{nick} #{usermode} * :#{fullname}")
            end

            def pong(data)
                raw("PONG :#{data}")
            end

            def join(channels, keys='')
                channels = to_array(channels)
                keys = to_array(keys)

                msg = "JOIN #{channels.join(',')}"
                msg += " #{keys.join(',')}" if keys.length > 0
                raw(msg)
            end

            def part(channels, msg=nil)
                channels = to_array(channels)
                msg = "PART #{channels.join(',')}"
                msg += " :#{msg}" unless msg.nil?
                raw(msg)
            end

            def mode(channel, modes, operands=nil)
                operands = to_array(operands) if operands
                msg = "MODE #{channel} #{modes}"
                msg += " #{operands.join(' ')}" if operands
                raw(msg)
            end

            def topic(channel, topic=nil)
                msg = "TOPIC #{channel}"
                msg += " :#{topic}" if topic
                raw(msg)
            end

            def invite(nick, channel)
                raw("INVITE #{nick} #{channel}")
            end

            def kick(channels, users, comment=nil)
                channels = to_array(channels)
                users = to_array(users)
                msg = "KICK #{channels.join(',')} #{users.join(',')}"
                msg += " :#{comment}" if comment
                raw(msg)
            end

            def privmsg(channel, msg)
                raw("PRIVMSG #{channel} :#{msg}")
            end

            def notice(channel, msg)
                raw("NOTICE #{channel} :#{msg}")
            end

            def quit(msg)
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
