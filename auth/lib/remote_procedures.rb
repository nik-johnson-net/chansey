module Chansey
    module Auth
        module RemoteProcedures
            def on_register(request)
                params = {
                    'network' => String,
                    'nick' => String,
                    'password' => String
                }

                return if !verify_params(request, params)
                
            end
        end
    end
end
