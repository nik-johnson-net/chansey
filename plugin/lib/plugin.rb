require 'fiber'

module Chansey
    class Plugin
        attr_reader :metadata

        @initializers = []

        # Override new so superclasses don't have to call super.
        def self.new(interface, log, config, name, file, other_meta={})
            allocate.instance_eval do
                @interface = interface
                @log = log
                @config = config
                @metadata = {
                    :name => name,
                    :filename => file
                }

                @metadata.merge!(other_meta)
                @_event_handlers = {}

                interface.new_plugin(self)

                add_event_callback(&method(:_event_handler))

                self.class.initializers.each do |block|
                    self.instance_eval(&block)
                end

                initialize
                self
            end
        end

        def self.initializers
            @initializers
        end

        def self.initializer(&block)
            @initializers << block
        end

        # detect inherited
        def self.inherited(subclass)
            @@latest_inherited = subclass

            subclass.class_eval do
                @initializers = []
            end
        end

        def self.latest_plugin
            @@latest_inherited
        end

        # Stub
        def initialize(*args)
        end

        # stub
        def on_event(m, p)
        end

        def rpc(service, command, opts)
            @interface.rpc(@metadata[:name], service, command, opts)
        end

        # Returns (true|false), args...
        def wait_for_deferrable(deferrable)
            @interface.sync_deferrable(@metadata[:name], deferrable)
        end

        def lock(&block)
            @interface.capture_lock(@metadata[:name])
            yield
            @interface.release_lock(@metadata[:name])
        end

        def on_unload
        end

        def listen_for(*routing_keys)
            routing_keys.map! { |x| "#{@config['amqp']['exchange']}.event.#{x}" }
            routing_keys.each do |routing_key|
                @interface.add_binding(@metadata[:name], routing_key)
            end
        end

        def stop_listening_for(*routing_keys)
            routing_keys.each do |routing_key|
                @interface.remove_binding(@metadata[:name], routing_key)
            end
        end

        def add_event_callback(&block)
            @interface.add_event_callback(@metadata[:name], &block)
        end

        def handle_event(event, &block)
            event = "chansey.event.#{event}"
            @_event_handlers[event] = [] if @_event_handlers[event].nil?
            @_event_handlers[event] << block
        end

        def _event_handler(metadata, payload)
            runners = @_event_handlers[metadata.routing_key]
            if runners
                runners.each do |p|
                    p.call(payload)
                end
            end
        end
    end
end
