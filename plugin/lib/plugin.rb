module Chansey
    class Plugin
        attr_reader :metadata

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

                interface.new_plugin(self)
                initialize(config)
                self
            end
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

        def deferrable_sync
        end

        def lock(&block)
            @interface.capture_lock(@metadata[:name])
            yield
            @interface.release_lock(@metadata[:name])
        end

        def on_unload
        end

        def listen_for(routing_key)
            @interface.add_binding(@metadata[:name], routing_key)
        end

        def stop_listening_for(routing_key)
            @interface.remove_binding(@metadata[:name], routing_key)
        end

        def add_event_callback(&block)
            @interface.add_event_callback(@metadata[:name], &block)
        end
    end
end
