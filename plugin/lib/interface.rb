require 'json'
require 'fiber'
require_relative '../../common/event'
require_relative '../../common/string'

module Chansey
    module Plugins
        class Interface
            TIMEOUT = 5
            attr_reader :locks
            attr_reader :event_callbacks
            attr_reader :queues

            def initialize(log, amqp_channel, amqp_exchange)
                @locks = {}
                @lock_wait = {}
                @event_callbacks = {}
                @queues = {}
                @rply_queues = {}

                @log = log
                @channel = amqp_channel
                @exchange = amqp_exchange

                @fiber_reply_map = {}
                @idgen = Common::EventIdGenerator.new
            end

            def new_plugin(plugin)
                name = plugin.metadata[:name]
                @log.debug "Loading new plugin #{name}"

                # Sanity check
                if @locks[name] or @event_callbacks[name] or @queues[name] or @rply_queues[name]
                    raise ArgumentError, "Plugin is already loaded"
                end

                @locks[name] = nil
                @lock_wait[name] = []
                @event_callbacks[name] = [plugin.method(:on_event)]

                ## Bind callback queue
                @rply_queues[name] = new_queue(name, '') do |q|
                    q.bind(@exchange, :routing_key => q.name)
                    q.subscribe(&reply_handler_factory(name))
                end

                # Bind primary queue
                @queues[name] = new_queue(name, '') do |q|
                    q.subscribe(&message_handler_factory(name))
                end

                plugin
            end

            def unload_plugin(plugin)
                name = plugin.metadata[:name]

                # Call plugin's callback
                plugin.on_unload

                # Unbind queues
                remove_binding(name)
                @rply_queues[name].unbind(@exchange)

                # Remove entries
                @locks.delete name
                @lock_wait.delete name
                @event_callbacks.delete name
                @queues.delete name
                @rply_queues.delete name
                nil
            end

            def new_queue(plugin_name, name, opts={ :auto_delete => true }, &block)
                @channel.queue(name, opts, &block)
            end

            def add_binding(plugin_name, binding)
                @queues[plugin_name].bind(@exchange, :routing_key => binding)
            end

            def remove_binding(plugin_name, binding=nil)
                @queues[plugin_name].unbind(@exchange, :routing_key => binding)
            end

            def capture_lock(plugin_name)
                if @locks[plugin_name]
                    @lock_wait[plugin_name] << Fiber.current
                    Fiber.yield
                else
                    @locks[plugin_name] = Fiber.current
                end
            end

            def release_lock(plugin_name)
                unless Fiber.current == @locks[plugin_name]
                    raise "Attempted to release another fiber's lock"
                end

                @locks[plugin_name] = nil
            end

            def rpc(plugin_name, service, command, opts)
                id = @idgen.new_id

                payload = {
                    :type => 'cmd',
                    :timestamp => Time.now.to_i,
                    :id => id,
                    :command => command,
                    :origin => plugin_name,
                    :opts => opts
                }

                topic_opts = {
                    :reply_to => @rply_queues[plugin_name].name,
                    :routing_key => "chansey.service.#{service.amqp_safe}"
                }
                @exchange.publish(payload.to_json, topic_opts)

                timer = EM::Timer.new(TIMEOUT, &rpc_timeout_callback_factory(id))

                @fiber_reply_map[id] = {
                    :fiber => Fiber.current,
                    :timer => timer
                }
            end

            def add_event_callback(plugin_name, &method)
                @event_callbacks[plugin_name] << method
            end

            private

            def reply_handler_factory(plugin_name)
                Proc.new do |meta, payload|
                    begin
                        payload = JSON.parse(payload)
                    rescue JSON::ParseError
                        return
                    end

                    unless payload['type'] == 'cmdrply'
                    end

                    fiber = @fiber_reply_map[payload['id']]

                    if fiber.nil?
                    end

                    @fiber_reply_map.delete payload['id']

                    if @locks[plugin_name].nil? or @locks[plugin_name] == fiber[:fiber]
                        @locks[plugin_name] = nil
                        fiber[:timer].cancel
                        fiber[:fiber].resume payload
                    else
                        @lock_wait[plugin_name] << {
                            :fiber => fiber,
                            :args => [payload]
                        }
                    end
                end
            end

            def message_handler_factory(plugin_name)
                Proc.new do |meta, payload|
                    payload = JSON.parse(payload)

                    fiber = Fiber.new do
                        @event_callbacks[plugin_name].each do |m|
                            begin
                                m.call(meta, payload)
                            rescue => e
                                if @locks[plugin_name] == fiber
                                    @locks[plugin_name] = nil 
                                end

                                @log.warn "Exception on new event:
                                    #{e.exception}: #{e.message}
                                    \n#{e.backtrace.join("\n")}"
                            end
                        end

                        next_fiber = @lock_wait[plugin_name].first
                        unless next_fiber.nil?
                            next_fiber[:fiber].resume *next_fiber[:args]
                        end
                    end

                    if @locks[plugin_name]
                        @lock_wait[plugin_name] << {
                            :fiber => fiber,
                            :args => [meta, payload]
                        }
                    else
                        fiber.resume meta, payload
                    end
                end
            end

            def rpc_timeout_callback_factory(id)
                Proc.new do
                    @log.warn "RPC call id #{id} timed out"
                    fiber = @fiber_reply_map[id]
                    @fiber_reply_map.delete id

                    fiber[:fiber].resume false, "Request timed out"
                end
            end
        end
    end
end
