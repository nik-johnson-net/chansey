require_relative '../../common/string'
require_relative 'account.rb'
require_relative '../../common/service'

module Chansey
    module Email
        class Controller < Common::Service

            def initialize(log, config, restart)
                super
                @accounts = {}

                @config['accounts'].each do |config|
                    new_account = Email::Account.new(
                        @log,
                        config['email'],
                        config['server'],
                        config['port'],
                        config['ssl'],
                        &method(:on_new_email)
                    )
                    new_account.login( config['password'] ) do
                        new_account.handle_unread_emails do |*args|
                            on_new_email(*args)
                        end.callback do
                            new_account.idle( &method(:on_new_email) )
                        end
                    end

                    @accounts[config['email']] = new_account
                end
            end # End init

            def on_new_email(from, to, subject, body)
                data = {
                    :from => from,
                    :to => to,
                    :subject => subject,
                    :body => body
                }
                event = @egen.event('new', data)
                route = "chansey.event.#{@config['service_name'].amqp_safe}.#{event[:event]}"
                @exchange.publish(event.to_json, :routing_key => route)
                @log.debug "Published #{event} to #{route}"
            end # End on_new_email
        end # End controller
    end # End Email
end # End Chansey
