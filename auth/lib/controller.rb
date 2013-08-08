require_relative '../../common/service'
require_relative 'db_factory'
require 'securerandom'
require 'yaml'
require 'set'

require 'pry'

##
# DOCS

module Chansey
    module Auth
        class Controller < Common::Service
            def initialize(log, config, restart)
                @log = log
                @statements = YAML.load_file( File.expand_path('../statements.yaml', __FILE__) )

                @authenticated_users = Set.new

                dbcon = config['database']
                @db_factory = DBFactory.new({
                    :host                => dbcon['host'],
                    :port                => dbcon['port'],
                    :user                => dbcon['user'],
                    :password            => dbcon['pass'],
                    :sslmode             => 'allow',
                    :dbname              => 'chansey',
                    :async_autoreconnect => true,
                    :query_timeout       => 5,
                    :connect_timeout     => 5
                })

                @db = @db_factory.new_connection
                log.info "Connected to the database."

                create_accounts_table do
                    create_nicks_table do
                        create_permissions_table
                        super

                        authenticate_user('net', 'nick6', 'asdf')
                    end
                end

            end


            ##
            # Register a new user
            def register_user(network, nick, password)
                password = password.crypt('$6$' + SecureRandom.base64(8))

                db = @db_factory.new_connection
                exec_statement(db, :register_user, password, network, nick) do |result|

                    if result.is_a? PG::UniqueViolation
                        @log.debug("Query #{network}, #{nick} failed - #{result.message.rstrip!}")
                        yield false, 'User is already registered' if block_given?

                    elsif result.is_a? ::Exception
                        @log.debug("Query #{network}, #{nick} failed - #{result.message.rstrip!}")
                        yield false, result.message if block_given?

                    else
                        @log.debug("Query #{network}, #{nick} succeeded")
                        yield true, 'Success' if block_given?

                    end
                end
            end

            ##
            # link a new nick
            def link_user(old_network, old_nick, new_network, new_nick)
                db = @db_factory.new_connection
                exec_statement(db, :link_user, new_network, new_nick, old_network, old_nick) do |result|

                    if result.is_a? PG::UniqueViolation
                        @log.debug("Link user #{old_network}, #{old_nick} to #{new_network}, #{new_nick} failed - #{result.message.rstrip!}")
                        yield false, 'User is already registered' if block_given?

                    elsif result.is_a? ::Exception
                        @log.debug("Link user #{old_network}, #{old_nick} to #{new_network}, #{new_nick} failed - #{result.message.rstrip!}")
                        yield false, result.message if block_given?

                    else
                        @log.debug("Link user #{old_network}, #{old_nick} to #{new_network}, #{new_nick} succeeded")

                        if result.cmd_tuples > 0
                            yield true, 'Success' if block_given?
                        else
                            yield false, 'Current nick is not registered' if block_given?
                        end

                    end
                end
            end

            ##
            # Delete an old user
            def delete_nick(network, nick)
                db = @db_factory.new_connection
                exec_statement(db, :delete_nick, network, nick) do |result|

                    if result.is_a? ::Exception
                        @log.debug("Delete user #{network}, #{nick} failed- #{result.message.rstrip!}")
                        yield false, result.message if block_given?

                    else
                        @log.debug("Delete user #{network}, #{nick} succeeded")

                        if result.cmd_tuples > 0
                            yield true, 'Success' if block_given?
                        else
                            yield false, 'Nick is not registered' if block_given?
                        end

                    end
                end
            end

            ##
            # Authenticate
            def authenticate_user(network, nick, password)
                if @authenticated_users.include? "#{network}:#{nick}"
                    yield true, 'Already authenticated' if block_given?
                    return
                end

                db = @db_factory.new_connection
                exec_statement(db, :auth_user, network, nick) do |result|

                    if result.is_a? ::Exception
                        @log.debug("Auth user #{network}, #{nick} failed- #{result.message.rstrip!}")
                        yield false, result.message if block_given?

                    else
                        @log.debug("Auth user #{network}, #{nick} succeeded")

                        if result.cmd_tuples > 0
                            salt = result.first['password'].rpartition('$').first
                            if password.crypt(salt) == result.first['password']
                                @log.debug("Authenticated #{network}:#{nick}")
                                @authenticated_users << "#{network}:#{nick}"

                                yield true, 'Success' if block_given?
                            else
                                @log.debug("Worng password #{network}:#{nick}")
                                yield false, 'Incorrect password' if block_given?
                            end
                        else
                            @log.debug("No User for auth #{network}:#{nick}")
                            yield false, 'Nick is not registered' if block_given?
                        end

                    end
                end
            end

            ##
            # Authorize
            def authorize_user(network, nick, permission)
                if !@authenticated_users.include? "#{network}:#{nick}"
                    yield false, 'User not authenticated' if block_given?
                    return
                end

                # Recursively generate the SIMILAR TO parameter
                permissions = permission.split('.')
                subregex = lambda do |array|
                      "(\.#{array.shift}#{subregex.call(array) if !array.empty?})?"
                end
                similar_to = "#{permissions.shift}#{subregex.call(permissions) if !subregex.empty?}"


                db = @db_factory.new_connection
            end

            ##
            # Deauthenticate
            def deauthenticate_user(network, nick)
                @authenticated_users.delete("#{network}:#{nick}")
                yield true, 'Success' if block_given?
            end

            private
            def create_accounts_table
                deffer = @db.async_exec(@statements['create_accounts'])
                deffer.callback do |x|
                    x.clear
                    yield if block_given?   
                end.errback do |x|
                    @log.fatal("Fatal create table 'accounts': #{x}")
                    EM.stop
                end
            end

            def create_nicks_table
                deffer = @db.async_exec(@statements['create_nicks'])
                deffer.callback do |x|
                    x.clear
                    yield if block_given?
                end.errback do |x|
                    @log.fatal("Fatal create table 'nicks': #{x}")
                    EM.stop
                end
            end

            def create_permissions_table
                deffer = @db.async_exec(@statements['create_perms'])
                deffer.callback do |x|
                    x.clear
                    yield if block_given?
                end.errback do |x|
                    @log.fatal("Fatal create table 'permissions': #{x}")
                    EM.stop
                end
            end

            def exec_statement(db, stmt, *params, &block)
                db.prepare(stmt.to_s, @statements[stmt.to_s]) do |r|
                    if r.is_a? ::Exception
                        @log.error("Prepare failed: #{r.message}")
                    else
                        r.clear
                        db.exec_prepared(stmt.to_s, params, &block)
                    end
                end
            end
        end
    end
end
