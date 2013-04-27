class String
    def amqp_safe
        str = ""
        each_char do |c|
            case c
            when /[0-9a-z]/
                str += c
            when /[A-Z]/
                str += "C#{c.downcase}"
            else
                str += "X#{c.unpack('C')[0].to_s(16).upcase}"
            end
        end

        return str
    end
end

module Chansey
    class PluginWrapper
        TIMEOUT = 5
        attr_reader :log

        def initialize(logger)
            @log = logger
            @fiber_map = {}
            @blocking = false
            @local_queue = EM::Queue.new
            @last_timestamp = {
                :timestamp => Time.now.to_i,
                :counter => 0
            }
            amqp_connect
        end

        def load(file)
            Kernel.load file
            @plugin = Chansey::Plugin.spawn_plugin(self)


            # Configure the bindings
            Chansey::Plugin.bindings.each do |b|
                @queue.bind(@exchange, :routing_key => b)
            end

            # Post init callback
            @plugin.init

            # Finally, subscribe the handlers
            @queue.subscribe(&method(:queue_handler))
            @reply_queue.subscribe(&method(:reply_handler))
        end

        def remote_call(service, command, opts)
            # Generate ID
            timestamp = Time.now.to_i
            if timestamp == @last_timestamp[:timestamp]
                @last_timestamp[:counter] += 1
            else
                @last_timestamp[:timestamp] = timestamp
                @last_timestamp[:counter] = 0
            end
            id = "%d%d%06d" % [ Process.pid, timestamp, @last_timestamp[:counter] ]

            payload = {
                :type => "cmd",
                :timestamp => timestamp,
                :id => id,
                :command => command,
                :origin => 'sample',
                :opts => opts
            }
            @exchange.publish(payload.to_json, { :reply_to => @reply_queue.name, :routing_key => "chansey.service.#{service.amqp_safe}" } )
            @blocking = true

            @log.debug "Yielding for RPC call"
            @fiber_map[id] = Fiber.current
            EM.add_timer(TIMEOUT) do
                @log.debug "Timeout fired"
                f = @fiber_map[id]
                if f
                    @fiber_map.delete id
                    @blocking = false
                    f.resume

                    @local_queue.pop do |m, p|
                        @log.debug "Starting fiber from local queue"
                        (Fiber.new { call_plugin_callbacks(m, p) }).resume
                    end
                end
            end

            reply = Fiber.yield

            @log.debug "Resumed with reply #{reply}"
            return reply
        end

        private
        def amqp_connect(address='127.0.0.1')
            # Connect to amqp
            @amqp = AMQP.connect(:host => address)
            @log.info "Connected to AMQP Broker"

            # Create channel and connect to exchange
            @mq = AMQP::Channel.new(@amqp)
            @exchange = @mq.topic("chansey")

            # Define queue for new messages and another for rpc replies
            @queue = @mq.queue('', :auto_delete => true)
            @reply_queue = @mq.queue('', :auto_delete => true) do |q, declare_ok|
                q.bind(@exchange, :routing_key => q.name)
                # q.bind(@exchange, :routing_key => q.name)
            end
        end

        def queue_handler(meta, payload)
            @log.debug "Got #{payload}"

            payload = JSON.parse(payload)

            if @blocking
                @log.debug "Adding to local queue due to blocking"
                @local_queue << [meta, payload]
            else
                @log.debug "Starting fiber"
                (Fiber.new { call_plugin_callbacks(meta, payload) }).resume
            end
        end

        def reply_handler(meta, payload)
            @log.debug "Got in RPC Queue #{payload}"

            begin
                payload = JSON.parse(payload)
            rescue => e
                @log.warn "Received bad JSON in reply queue: #{e.exception}\n#{e.backtrace}"
                return
            end
            return if payload['type'] != 'cmdrply'

            fiber = @fiber_map[payload['id']]
            return if fiber.nil?

            @fiber_map.delete payload['id']
            @blocking = false
            fiber.resume(payload)

            @local_queue.pop do |m, p|
                @log.debug "Starting fiber from local queue"
                (Fiber.new { call_plugin_callbacks(meta, payload) }).resume
            end
        end

        def call_plugin_callbacks(*args)
            @log.debug "Calling callbacks #{@plugin.event_methods}"
            @plugin.event_methods.each do |f|
                begin
                    f.call *args
                rescue => e
                    @log.warn "Exception calling method: #{e.exception}\n#{e.backtrace.join("\n")}"
                end
            end
        end
    end
end
