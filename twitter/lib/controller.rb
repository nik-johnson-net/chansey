require 'tweetstream'

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
        class Controller
            def initialize(log, config, restart)
                @log = log
                @config = config
                @restart = restart

                @twitter = TweetStream::Client.new(config['oauth'].keys_to_sym)
                @twitter.on_error(&method(:on_error))
                @twitter.on_reconnect(&method(:on_reconnect))
                @twitter.follow(config['follow'], &method(:new_status))
            end

            def new_status(status)
                @log.debug "New status: #{status.from_user} - #{status.full_text}"
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
