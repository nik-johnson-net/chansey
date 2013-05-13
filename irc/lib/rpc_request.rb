module Chansey
    module IRC
        class RPCRequest
            def initialize(exchange,metadata, payload)
                @meta = metadata
                @req = payload
                @exchange = exchange
            end

            def id
                @req['id']
            end

            def timestamp
                @req['timestamp']
            end

            def command
                @req['command']
            end

            def origin
                @req['origin']
            end

            def opts(key=nil)
                if key
                    return @req['opts'][key]
                else
                    return @req['opts']
                end
            end

            def reply_to_request(success, data)
                payload = {
                    :type => "cmdrply",
                    :timestamp => Time.now.to_i,
                    :id => id,
                    :success => success,
                    :data => data
                }
                @exchange.publish(payload.to_json, :routing_key => @meta.reply_to)
            end


            def failure(data=nil)
                reply_to_request(false, data)
            end

            def success(data=nil)
                reply_to_request(true, data)
            end
        end # End class
    end # End IRC
end # End Chansey
