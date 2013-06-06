# encoding: utf-8
#
require 'nokogiri'
require 'em-shorturl'

class RSSIRCBridge < Chansey::Plugin
    include IRCPlugin

    RSS_TEMPLATE = "[%{feed}] %{title}: %{body}"

    def initialize
        listen_for 'rss.newitem'
        handle_event 'rss.newitem', &method(:new_rss_item)

        @max_length = @config['rss_irc_bridge']['max_length']

        @bridge = {}
        @config['rss_irc_bridge']['bridges'].each do |v|
            feed = v['feed_title']
            @bridge[feed] = {}
            v['networks'].each do |net|
                network = net['network']
                @bridge[feed][network] = net['channels'].dup
            end
        end

    end

    def new_rss_item(event)
        rss = event['data']
        if sendmap = @bridge[rss['feed']]
            body = Nokogiri::HTML.parse(rss['summary']).content.strip
            link = shorten(rss['link'])
            msg = RSS_TEMPLATE % {
                :feed => rss['feed'],
                :title => rss['title'],
                :body => body
            }

            # Truncate
            if msg.length > @max_length
                msg = msg[0...@max_length-3] + "..."
            end

            # Append link
            msg += " (#{link})"
            
            # Send to all destinations
            sendmap.each do |net, chanlist|
                chanlist.each do |chan|
                    notice(net, chan, msg)
                end
            end
        end
    end

    def shorten(link)
        bool, response = wait_for_deferrable EM::ShortURL.shorten(link)
        response = link unless bool
        
        response
    end
end
