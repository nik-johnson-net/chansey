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
                    @accounts[config['email']] = Email::Account.new(
                        @log,
                        config['email'],
                        config['password'],
                        config['server'],
                        config['port'],
                        config['ssl']
                    )
                end
            end
        end
    end
end
