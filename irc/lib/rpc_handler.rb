require 'set'
require_relative 'rpc_request'

##
# Handles incoming RPC Requests

module Chansey
    module IRC
        class RPCHandler
            def initialize(log, service_name, amqp_channel, amqp_exchange, bot)
                @log = log
                @bot = bot
                @exchange = amqp_exchange
                @channel = amqp_channel

                @log.info "Binding to routing key: chansey.service.#{service_name.amqp_safe}"
                @queue = @channel.queue('', :auto_delete => true)
                @queue.bind(@exchange, :routing_key => "chansey.service.#{service_name.amqp_safe}")
                @queue.subscribe(&method(:receive_request))
            end

            def receive_request(metadata, request)
                @log.debug "Received command: #{request}"

                begin
                    request = JSON.parse(request)
                    req = IRC::RPCRequest.new(@exchange, metadata, request)
                    method_name = "on_#{req.command}"

                    if respond_to?(method_name)
                        method(method_name).call(req)
                    else
                        @log.warn "Received RPC Request for unknown command '#{req.command}' from '#{req.origin}'"
                    end
                rescue => e
                    @log.warn "Received bad message and threw #{e.exception}\n#{e.backtrace.join("\n")}"
                end
            end

            
            ##
            # Requests

            def on_raw(request)
                params = {
                    'network' => String,
                    'line'    => String
                }

                return if !verify_params(request, params)
                net = @bot.networks[request.opts("network")]
                return if !verify_network(request, net)

                net.raw(request.opts("line"))
                request.success
            end

            def on_nick(request)
                params = {
                    'network' => String,
                    'nick'    => String
                }

                return if !verify_params(request, params)
                net = @bot.networks[request.opts("network")]
                return if !verify_network(request, net)

                net.nick(request.opts("nick"))
                request.success
            end

            def on_join(request)
                # Channels should be an array of hashes
                # channel = {
                #     <channel-name> => <password>
                # }
                params = {
                    'network' => String,
                    'channels' => Hash
                }

                return if !verify_params(request, params)
                net = @bot.networks[request.opts("network")]
                return if !verify_network(request, net)

                net.join(request.opts("channels").keys, request.opts("channels").values)
                request.success
            end

            def on_part(request)
                params = {
                    'network' => String,
                    'channels' => Array
                }

                return if !verify_params(request, params)
                net = @bot.networks[request.opts("network")]
                return if !verify_network(request, net)

                net.part(request.opts("channels"), request.opts("msg"))
                request.success
            end

            def on_mode(request)
                params = {
                    'network' => String,
                    'channel' => String,
                    'modes' => String
                }

                return if !verify_params(request, params)
                net = @bot.networks[request.opts("network")]
                return if !verify_network(request, net)

                net.mode(request.opts("channel"), request.opts("modes"), request.opts("operands"))
                request.success
            end

            def on_topic(request)
                params = {
                    'network' => String,
                    'channel' => String,
                    'topic'   => String
                }

                return if !verify_params(request, params)
                net = @bot.networks[request.opts("network")]
                return if !verify_network(request, net)

                net.topic(request.opts("channel"), request.opts("topic"))
                request.success
            end

            def on_invite(request)
                params = {
                    'network' => String,
                    'channel' => String,
                    'nick'    => String
                }

                return if !verify_params(request, params)
                net = @bot.networks[request.opts("network")]
                return if !verify_network(request, net)

                net.invite(request.opts("nick"), request.opts("channel"))
                request.success
            end

            def on_kick(request)
                params = {
                    'network' => String,
                    'channels' => Array,
                    'nicks'    => Array 
                }

                return if !verify_params(request, params)
                net = @bot.networks[request.opts("network")]
                return if !verify_network(request, net)

                net.invite(request.opts("channels"), request.opts("nicks"), request.opts("msg"))
                request.success
            end


            def on_privmsg(request)
                params = {
                    'channel' => String,
                    'network' => String,
                    'msg'     => String
                }

                # verify opts exist
                return if !verify_params(request, params)

                # verify network exists
                net = @bot.networks[request.opts("network")]
                return if !verify_network(request, net)

                net.privmsg(request.opts("channel"), request.opts("msg"))
                request.success
            end

            def on_notice(request)
                params = {
                    'channel' => String,
                    'network' => String,
                    'msg'     => String
                }

                # verify opts exist
                return if !verify_params(request, params)

                # verify network exists
                net = @bot.networks[request.opts("network")]
                return if !verify_network(request, net)

                net.notice(request.opts("channel"), request.opts("msg"))
                request.success
            end

            def on_quit(request)
                params = {
                    'network' => String,
                }

                # verify opts exist
                return if !verify_params(request, params)

                # verify network exists
                net = @bot.networks[request.opts("network")]
                return if !verify_network(request, net)

                net.notice(request.opts("msg"))
                request.success
            end

            private
            def verify_network(request, network)
                if !network
                    request.failure( :reason => "Network does not exist" )
                    return false
                elsif !network.server
                    request.failure( :reason => "Network is not connected" )
                    return false
                else
                    return true
                end
            end

            def verify_params(request, params)
                @log.debug "Verifying params: Request: #{request}; Params: #{params}"

                if !params.keys.to_set.subset? request.opts.keys.to_set
                    request.failure( :reason => "Missing Parameters (#{request.command} requires #{params.keys.join(', ')}" )
                    return false
                else
                    return true
                end
            end
        end # End class
    end # End IRC
end # End Chansey
