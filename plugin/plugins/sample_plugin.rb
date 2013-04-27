# encoding: utf-8
class MyPlugin < Chansey::Plugin
    events 'irc.privmsg', 'irc.join', 'irc.ping'

    def init
        @myvar = 'text'
        puts "Init sample"
    end

    def on_event(metadata, event)
        puts "event"
        case event['event']
        when 'privmsg'
            puts "yay privmsg"
            if event['data']['msg']['command'] == 'privmsg' and event['data']['msg']['params'] == 'join'
                rply = rpc('irc', 'join', { :channels => {'#tamulug' => ''}, :network => 'cognet' })
                if rply.nil?
                    puts "Response timed out"
                else
                    puts rply
                end
            elsif event['data']['msg']['params'] =~ /こんなに殺すのができるか?/
                rply = rpc('irc', 'notice', {:network => 'cognet', :channel => event['data']['msg']['nick'], :msg => 'Fuck you.' })
            end
        when 'join'
            puts "yay join"
        when 'ping'
            puts "yay ping"
        else
            puts "whoops got something else"
        end
    end
end

