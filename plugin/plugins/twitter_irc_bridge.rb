# encoding: utf-8

class TwitterIRCBridge < Chansey::Plugin
    include IRCPlugin

    TWEET_TEMPLATE = "[twitter] %{user}: %{body}"

    def initialize
        listen_for 'twitter.tweet'
        handle_event 'twitter.tweet', &method(:new_tweet)

        @bridge = {}
        @config['twitter_irc_bridge']['bridges'].each do |v|
            feed = v['handle'].downcase
            @bridge[feed] = {}
            v['networks'].each do |net|
                network = net['network']
                @bridge[feed][network] = net['channels'].dup
            end
        end

    end

    def new_tweet(event)
        @log.debug event
        tweet = event['data']
        if sendmap = @bridge[tweet['user'].downcase]
            msg = TWEET_TEMPLATE % {
                :user => tweet['user'],
                :body => tweet['text']
            }

            # Send to all destinations
            sendmap.each do |net, chanlist|
                chanlist.each do |chan|
                    notice(net, chan, msg)
                end
            end
        end
    end
end
