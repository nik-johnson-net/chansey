require 'set'

class Chansey::IRC::Request
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
        puts "Meta: #{@meta}"
        puts "Reply: #{@meta.reply_to}"
        @exchange.publish(payload.to_json, :routing_key => @meta.reply_to)
    end


    def failure(data=nil)
        reply_to_request(false, data)
    end

    def success(data=nil)
        reply_to_request(true, data)
    end
end
    
module Chansey::IRC::Requests
    FUNCTIONS = [ 'raw', 'nick', 'join', 'part', 'mode', 'topic', 'invite',
        'kick', 'privmsg', 'notice', 'quit' ].to_set
    private
    def route_request(request)
        if FUNCTIONS.include? request.command
            method(request.command.to_sym).call(request)
        else
            @log.warn "Received unknown command #{request.command} from #{request.origin}"
        end
    end

    def verify_network(request, network)
        if !network
            request.failure( :reason => "Network does not exist" )
            return false
        end

        if !network.server
            request.failure( :reason => "Network is not connected" )
            return false
        end
        true
    end

    def verify_params(request, params)
        p request.opts.keys
        p params.keys
        # if request.opts.keys & params.keys != params.keys
        if !params.keys.to_set.subset? request.opts.keys.to_set
            request.failure( :reason => "Missing Parameters (#{request.command} requires #{params.keys.join(', ')}" )
            return false
        end
        return true
    end

    def raw(request)
        params = {
            'network' => String,
            'line'    => String
        }

        return if !verify_params(request, params)
        net = @networks[request.opts("network")]
        return if !verify_network(request, net)

        net.raw(request.opts("line"))
        request.success
    end

    def nick(request)
        params = {
            'network' => String,
            'nick'    => String
        }

        return if !verify_params(request, params)
        net = @networks[request.opts("network")]
        return if !verify_network(request, net)

        net.nick(request.opts("nick"))
        request.success
    end

    def join(request)
        # Channels should be an array of hashes
        # channel = {
        #     <channel-name> => <password>
        # }
        params = {
            'network' => String,
            'channels' => Hash
        }

        return if !verify_params(request, params)
        net = @networks[request.opts("network")]
        return if !verify_network(request, net)

        net.join(request.opts("channels").keys, request.opts("channels").values)
        request.success
    end

    def part(request)
        params = {
            'network' => String,
            'channels' => Array
        }

        return if !verify_params(request, params)
        net = @networks[request.opts("network")]
        return if !verify_network(request, net)

        net.part(request.opts("channels"), request.opts("msg"))
        request.success
    end

    def mode(request)
        params = {
            'network' => String,
            'channel' => String,
            'modes' => String
        }

        return if !verify_params(request, params)
        net = @networks[request.opts("network")]
        return if !verify_network(request, net)

        net.mode(request.opts("channel"), request.opts("modes"), request.opts("operands"))
        request.success
    end

    def topic(request)
        params = {
            'network' => String,
            'channel' => String,
            'topic'   => String
        }

        return if !verify_params(request, params)
        net = @networks[request.opts("network")]
        return if !verify_network(request, net)

        net.topic(request.opts("channel"), request.opts("topic"))
        request.success
    end

    def invite(request)
        params = {
            'network' => String,
            'channel' => String,
            'nick'    => String
        }

        return if !verify_params(request, params)
        net = @networks[request.opts("network")]
        return if !verify_network(request, net)

        net.invite(request.opts("nick"), request.opts("channel"))
        request.success
    end

    def kick(request)
        params = {
            'network' => String,
            'channels' => Array,
            'nicks'    => Array 
        }

        return if !verify_params(request, params)
        net = @networks[request.opts("network")]
        return if !verify_network(request, net)

        net.invite(request.opts("channels"), request.opts("nicks"), request.opts("msg"))
        request.success
    end


    def privmsg(request)
        params = {
            'channel' => String,
            'network' => String,
            'msg'     => String
        }

        # verify opts exist
        return if !verify_params(request, params)

        # verify network exists
        net = @networks[request.opts("network")]
        return if !verify_network(request, net)

        net.privmsg(request.opts("channel"), request.opts("msg"))
        request.success
    end

    def notice(request)
        params = {
            'channel' => String,
            'network' => String,
            'msg'     => String
        }

        # verify opts exist
        return if !verify_params(request, params)

        # verify network exists
        net = @networks[request.opts("network")]
        return if !verify_network(request, net)

        net.notice(request.opts("channel"), request.opts("msg"))
        request.success
    end

    def quit(request)
        params = {
            'network' => String,
        }

        # verify opts exist
        return if !verify_params(request, params)

        # verify network exists
        net = @networks[request.opts("network")]
        return if !verify_network(request, net)

        net.notice(request.opts("msg"))
        request.success
    end
end
