class DefaultIRCPlugin < Chansey::Plugin
    include IRCPlugin

    BOT_TEMPLATE = "%{name} - Owner: %{owner} - Command Prefix: %{prefix}"

    def initialize
        @bots = @config['bots'].dup
        @bots.each do |network,channels|
            channels.each do |channel,bots|
                bots.map! do |bot|
                    bot.keys_to_sym
                end
            end
        end

        irc_command 'bots' do |req|
            req.notice("Bots for #{req.channel}:")

            @bots[req.network][req.channel].each do |b|
                req.notice(BOT_TEMPLATE % b)
            end
        end
    end
end
