module Chansey
    class Plugin
        attr_reader :event_methods
        @@bindings = []
        @@event_methods = [:on_event]
        @@module_inits = []

        def self.events(*args)
            @@bindings += args.map { |x| "chansey.event.#{x}" }
        end

        def self.event_handler(*args)
            @@event_methods += args
        end

        def self.module_init(*args)
            @@module_inits += args
        end

        def self.bindings
            @@bindings
        end

        def self.spawn_plugin(*args)
            @@subclass.new(*args)
        end

        def self.inherited(subclass)
            @@subclass = subclass
        end

        def initialize(wrapper)
            @wrapper = wrapper
            @log = wrapper.log
            @@event_methods.map! { |f| method(f) }
            @@module_inits.map! { |f| method(f) }
            @@module_inits.each do |x|
                x.call
            end
        end

        def event_methods
            @@event_methods
        end

        def init
        end

        def rpc(service, command, opts)
            @wrapper.remote_call(service, command, opts)
        end

        def on_event(meta, event)
        end
    end
end
