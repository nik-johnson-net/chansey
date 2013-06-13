require 'json'

class MurmurPlugin < Chansey::Plugin
    include IRCPlugin

    EXECUTE_TEMPLATE = "/usr/bin/env python %{query_exec} %{ip} %{port}"

    def initialize
        irc_command("mumble", {:priv => true}, &method(:query_murmur_ice))
        @shell_line = EXECUTE_TEMPLATE % {
            :query_exec => @config['mumble']['ice_query_exec'],
            :ip => @config['mumble']['ice']['ip'],
            :port => @config['mumble']['ice']['port']
        }
    end

    def query_murmur_ice(request)
        response_string = "Mumble server: #{@config['mumble']['address']}:#{@config['mumble']['port']} - "

        d = EM::DeferrableChildProcess.open(@shell_line)
        bool, data = wait_for_deferrable d
        unless bool
            @log.warn "Failed child process: #{data}"
            return nil
        end

        unless d.get_status.success?
            request.notice(response_string + "Failed to query server")
            return nil
        end

        info = JSON.parse(data)
        response_string += "Version: #{info['version']} - "
        response_string += "Users: #{info['users'].join(', ')}"

        request.notice(response_string)
    end
end
