class DefaultIRCPlugin < Chansey::Plugin
    include IRCPlugin
    SOURCE_LINK = "https://github.com/jumpandspintowin/chansey"
    SMILIES = [ ':3', 'd(^_^)b', '(>-.-)>' ]

    def initialize
        irc_command 'botsnack' do |req|
            req.privmsg(SMILIES.sample)
        end

        irc_command 'source' do |req|
            req.privmsg("#{req.nick}: #{SOURCE_LINK}")
        end
    end
end
