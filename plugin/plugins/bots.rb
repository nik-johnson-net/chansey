class DefaultIRCPlugin < Chansey::Plugin
    include IRCPlugin

    BOT_TEMPLATE = "%{name} - Owner: %{owner} - Command Prefix: %{prefix}"

    def initialize
        @bots = @config['bots']

        irc_command 'bots' do |req|
            req.notice("Bots for #{req.channel}:")

            @bots[req.network][req.channel].each do |b|
                req.notice(BOT_TEMPLATE % b)
            end
        end
    end
end
