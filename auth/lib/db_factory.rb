require 'pg/em'

module Chansey
    module Auth
        class DBFactory
            ##
            # Options for connecting as specified by PG::Connection
            def initialize(connect_opts)
                @connect_opts = connect_opts
            end

            def new_connection
                db = PG::EM::Client.new(@connect_opts)
                db.set_error_verbosity(PG::PQERRORS_TERSE)
                return db
            end
        end
    end
end
