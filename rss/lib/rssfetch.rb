require 'em-http-request'
require 'rss'

module Chansey
    module RSS
        class RSSFetch
            MAX_REDIRECTS = 5

            def initialize(controller, feed)
                @controller = controller
                @log = controller.log
                @feed_url = feed
                @last_item = Time.now
            end

            def fetch
                http = EventMachine::HttpRequest.new(@feed_url).get :redirects => MAX_REDIRECTS
                http.errback &method(:fetch_error)
                http.callback &method(:fetch_success)
            end

            def fetch_success(http)
                if http.redirects == 5
                    @log.warn "Feed for #{@feed_url} redirected more than #{MAX_REDIRECTS} times. Please verify the url."
                    return nil
                elsif http.redirects > 0
                    @log.warn "Feed for #{@feed_url} has moved to #{http.last_effective_url}. Please update the config file."
                end

                feed = ::RSS::Parser.parse(http.response)

                if feed.nil?
                    @log.warn "Feed for #{@feed_url} is not valid RSS"
                    return nil
                end

                latest_item = @last_item

                feed.items.each do |item|
                    next if item.date <= @last_item

                    # New item
                    latest_item = item.date if item.date > latest_item

                    event = {
                        :feed => feed.channel.title,
                        :feed_link => feed.channel.link,
                        :title => item.title,
                        :date => item.date.to_s,
                        :link => item.link,
                        :summary => item.description
                    }

                    @controller.create_event(event)
                end

                @last_item = latest_item
            end

            def fetch_error(http)
                @log.error "Unable to fetch feed #{@feed_url}: #{http.error}"
            end
        end
    end
end
