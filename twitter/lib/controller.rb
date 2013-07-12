require 'tweetstream'
require_relative '../../common/service'

class Hash
    def keys_to_sym
        new_hash = {}
        each do |k,v|
            new_hash[k.to_sym] = v
        end
        new_hash
    end
end

module Chansey
    module Twitter
        class Controller < Common::Service
            def initialize(log, config, restart)
                super
                @twitter = TweetStream::Client.new(config['oauth'].keys_to_sym)
                @twitter.on_error(&method(:on_error))
                @twitter.on_reconnect(&method(:on_reconnect))
                @twitter.follow(config['follow'], &method(:new_status))
            end

            def new_status(status)
                @log.debug "New status: #{status.from_user} - #{status.full_text}"
                data = {
                    :user => status.from_user,
                    :userid => status.from_user_id,
                    :text => status.full_text,
                    :retweet => status.retweet?
                }

                event = @egen.event('tweet', data)
                route = "chansey.event.#{@config['service_name'].amqp_safe}.tweet"

                @exchange.publish(event.to_json, :routing_key => route)
                @log.debug "Pushed event to exchange: #{event}"
            end

            private
            def on_error(error)
                @log.error error
            end

            def on_reconnect(timeout, retries)
                @log.error "Reconnecting (#{retries})"
            end
        end
    end
end
