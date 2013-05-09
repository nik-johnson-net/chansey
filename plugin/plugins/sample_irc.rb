# encoding: utf-8
#
class MyPlugin < Chansey::Plugin
    include Chansey::Plugin::IRCPlugin
    SOURCE_LINK = "https://github.com/jumpandspintowin/chansey"
    events 'irc.privmsg'

    def init
        command("botsnack", {:priv => true}, &method(:botsnack))
        command("source", {:priv => true}, &method(:source))

        command("join", {:priv => true}) do |e|
            params = e['data']['msg']['params']
            join(e['data']['network'], params.split[1..-1])
        end

        command("say") do |e|
            params = e['data']['msg']['params']
            privmsg(e['data']['network'],
                    e['data']['msg']['middle'].first,
                    params.partition(' ')[2])
        end

        @command_key = "."
    end

    def botsnack(event)
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

    def source(event)
        if event['data']['msg']['middle'][0][0] == '#'
            privmsg(event['data']['network'],
                    event['data']['msg']['middle'][0],
                    "source: #{SOURCE_LINK}")
        else
            privmsg(event['data']['network'],
                    event['data']['msg']['nick'],
                    "source: #{SOURCE_LINK}")
        end
    end
end
