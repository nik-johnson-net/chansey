require 'json'
require 'amqp'
require 'eventmachine'
require_relative 'hash'
require_relative 'event'
require_relative 'rpc'

module Chansey
    module Common

        ##
        # This is such a hack....
        # Gives a controlling class an easy way to signal the main method
        # that a fail-restart loop should continue.

        class RestartToggleClass
            attr_accessor :restart

            def initialize
                @restart = true
            end
        end


        ##
        # Service abstract class which contains much of the boiler plate code
        # for writing a service for Chansey.

        class Service
            attr_reader :log
            attr_reader :service_name

            def initialize(logger, config, restart=nil)
                @log = logger
                @restart = restart
                @config = config

                create_event_generator
                connect_to_amqp

                @rpc_handler = Common::RPCHandler.new(@log, @config['service_name'],
                                                      @mq, @exchange, self)
            end

            private
            def create_event_generator
                service = @config['service_name']
                raise KeyError, 'service_name must be set in the configuration file' if service.nil?

                @egen = Common::EventGenerator.new(service)
            end


            ##
            # See https://github.com/ruby-amqp/amqp/blob/master/lib/amqp/connection.rb#L185
            # for options.

            def connect_to_amqp
                unless @config['amqp'] and @config['amqp']['exchange']
                    raise KeyError, 'config file must define \'exchange\' under \'amqp\''
                end

                amqp_opts = @config['amqp'].keys_to_sym
                amqp_opts[:on_tcp_connection_failure] = method(:on_amqp_unbind)
                amqp_opts[:on_possible_authentication_failure] = method(:on_amqp_auth_fail)

                @amqp = AMQP.connect(amqp_opts) do
                    @log.info "Connected to AMQP Broker"
                end

                @mq = AMQP::Channel.new(@amqp)
                @exchange = @mq.topic(amqp_opts[:exchange])
            end


            ##
            # Called if AMQP disconnects.

            def on_amqp_unbind(opts)
                @log.fatal 'AMQP lost connection to server'
                @restart.restart = false
                EM.stop
            end


            ##
            # Called if AMQP Fails to authenticate

            def on_amqp_auth_fail
                @log.fatal 'Failed to authenticate with the AMQP server.'
                @restart.restart = false
                EM.stop
            end
        end
    end
end
