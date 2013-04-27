# encoding: utf-8
#
class MyPlugin < Chansey::Plugin
    include Chansey::Plugin::IRCPlugin
    events 'irc.privmsg'

    def init
        if !command("test", {:priv => true}, &method(:test_cmd))
            @log.warn "Couldn't register test, already in use"
        end

       command("join", {:priv => true}) do |e|
           params = e['data']['msg']['params']
           join(e['data']['network'], params.split[1..-1])
       end

       @command_key = "ಠ_ಠ"
    end

    def test_cmd(event)
        p event
        if event['data']['msg']['middle'][0][0] == '#'
            privmsg(event['data']['network'],
                    event['data']['msg']['middle'][0],
                    ":3")
        else
            privmsg(event['data']['network'],
                    event['data']['msg']['nick'],
                    ":3")
        end
    end
end
