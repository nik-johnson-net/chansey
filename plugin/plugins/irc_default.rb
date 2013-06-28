class DefaultIRCPlugin < Chansey::Plugin
    include IRCPlugin
    SOURCE_LINK = "https://github.com/jumpandspintowin/chansey"
    SMILIES = [ ':3', 'd(^_^)b', '(>-.-)>' ]

    def initialize
        irc_command 'botsnack' do |req|
            req.say(SMILIES.sample)
        end

        irc_command 'source' do |req|
            req.say("#{req.nick}: #{SOURCE_LINK}")
        end

        irc_command 'join' do |req|
            join(req.network, req.arg.partition(' ').first)
        end

        listen_for 'irc.invite'
        handle_event 'irc.invite' do |event|
            invited_channel = event['data']['msg']['params']
            join(event['data']['network'], invited_channel)
        end
    end
end
