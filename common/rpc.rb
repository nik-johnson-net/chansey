require 'set'

module Chansey
    module Common

        ##
        # Represents an RPC Request

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


        ##
        # Class for implementing RPC Callbacks
        # To add callbacks, simply call <instance>.extend(mixin), where mixin is a module of
        # instance functions of the form 'on_<call>'.

        class RPCHandler
            
            ##
            # Initialize with the necessary information. +controller+ is a variable
            # which is for use by the mixins. Normally should be the primary
            # interface to the service.

            def initialize(log, service, amqp_channel, amqp_exchange, controller)
                @log = log
                @controller = controller
                @exchange = amqp_exchange
                @channel = amqp_channel

                @log.info "Binding to routing key: chansey.service.#{service.amqp_safe}"
                @queue = @channel.queue('', :auto_delete => true)
                @queue.bind(@exchange, :routing_key => "chansey.service.#{service.amqp_safe}")
                @queue.subscribe(&method(:receive_request))
            end


            ##
            # This is the callback from AMQP upon a new RPC call. Malformed requests and
            # requests for undefined commands are dropped.

            def receive_request(metadata, request)
                @log.debug "Received command: #{request}"

                begin
                    request = JSON.parse(request)
                    req = Common::RPCRequest.new(@exchange, metadata, request)
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

            private
            def verify_params(request, params)
                @log.debug "Verifying params: Request: #{request}; Params: #{params}"

                if !params.keys.to_set.subset? request.opts.keys.to_set
                    request.failure( :reason => "Missing Parameters (#{request.command} requires #{params.keys.join(', ')}" )
                    return false
                else
                    return true
                end
            end
        end
    end
end
