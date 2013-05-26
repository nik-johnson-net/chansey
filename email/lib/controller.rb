require_relative 'account.rb'

module Chansey
    module Email
        class Controller
            attr_reader :log

            def initialize(log, config, restart)
                @log = log
                @config = config
                @restart = restart
                @accounts = {}

                @config['accounts'].each do |config|
                    new_account = Email::Account.new(
                        @log,
                        config['email'],
                        config['server'],
                        config['port'],
                        config['ssl']
                    )
                    new_account.login( config['password'] ) do
                        new_account.handle_unread_emails do |*args|
                            new_account.process_email(*args)
                        end.callback do
                            new_account.idle( &new_account.method(:process_email) )
                        end
                    end

                    @accounts[config['email']] = new_account
                end
            end # End init
        end # End controller
    end # End Email
end # End Chansey
