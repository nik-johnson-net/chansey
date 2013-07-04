# encoding: utf-8

MC_IRC_MAP = {
    "4" => "\x034",
    "c" => "\x034",
    "6" => "\x037",
    "e" => "\x038",
    "2" => "\x033",
    "a" => "\x039",
    "b" => "\x0310",
    "3" => "\x0311",
    "1" => "\x032",
    "9" => "\x036",
    "d" => "\x0313",
    "5" => "\x036",
    "f" => "\x030",
    "7" => "\x0314",
    "l" => "\x02",
    "n" => "\x01",
    "o" => "\x16",
    "r" => "\x0F\x03"
}

class ::String
    def mc_to_irc_colors
        newstr = gsub(/§(.)/) do |code|
            MC_IRC_MAP[$1]
        end
        newstr.insert(-1, "\x0F\x03")
        newstr
    end
end

class MCQuery < Chansey::Plugin
    include IRCPlugin
    QUERY_TEMPLATE = "%{server}: Players: %{players}/%{max_players} - Version: %{version} - MOTD: %{motd}"

    def initialize
        irc_command("mc", {:priv => true}, &method(:query_server))
    end

    def query_server(request)
        params = request.arg.split

        # Verify params are present
        unless params.length.between?(1,2)
            request.notice("Usage: <hostname> [port]")
            return
        end


        # Get basic query info
        bool, result = [nil, nil]
        begin
            bool, result = mc_query(*params)
        rescue EventMachine::ConnectionError => e
            request.notice("#{params.first}: #{e.message}")
            return
        end

        if !bool
            result ||= "Could not query the minecraft server."
            request.notice("#{params.first}: #{result}")
            return
        end

        if !result.players || !result.max_players || !result.version || !result.motd
            request.notice("#{params.first}: Missing parameter from server ping. Is the server broke?")
            return
        end

        # Set the result string
        result_string = QUERY_TEMPLATE % {
            :server      => params.first,
            :players     => result.players,
            :max_players => result.max_players,
            :version     => result.version,
            :motd        => result.motd.mc_to_irc_colors
        }

        # Add player list if available
        begin
            bool, result = ut3_query(*params)
        rescue EventMachine::ConnectionError => e
            request.notice("#{params.first}: #{e.message}")
            return
        end

        if bool
            result_string += " - Players: #{result.players.join(', ')}"
        end

        request.notice(result_string)
    end

    private
    # Uses the Server List query packet
    def mc_query(hostname, port='25565')
        mc = MinecraftPing.open(hostname, port)
        result = wait_for_deferrable mc.query
        mc.close_connection

        result
    end

    def ut3_query(hostname, port='25565')
        ut3 = UT3Query.open(hostname, port)
        bool, error = wait_for_deferrable ut3.handshake
        return bool, error unless bool

        result = wait_for_deferrable ut3.fullstat
        ut3.close_connection

        result
    end
end

# Minecraft optionally supports the UT3 query protocol
# This provides player information as well; We'll try it and see what happens

module UT3Query
    def self.open(server, port='25565')
        EM::open_datagram_socket('0.0.0.0', '0', Connection, server, port)
    end

    class Query
        attr_reader :players
        attr_reader :info

        def initialize(data)
            data.slice!(0..15)
            info, _, players = data.partition("\x00\x01player_\x00\x00")
            @info = Hash[*info.split("\x00")]
            @players = players.split("\x00")
        end
    end

    class Connection < EM::Connection
        STATES = [ :disconnected, :handshake, :connected ]
        RESPONSE_TIMEOUT = 5
        @@rand = Random.new

        def initialize(server, port)
            @server = server
            @port = port
            @id = @@rand.bytes(4).unpack('L').first & 0x0F0F0F0F
            @state = :disconnected
        end

        def handshake
            d = EM::DefaultDeferrable.new
            d.timeout(RESPONSE_TIMEOUT)

            if @state != :disconnected
                d.fail "Already connected or awaiting handshake response"
            else
                @state = :handshake
                @pending_query = d
                packet = [0xFE, 0xFD, 0x09, @id].pack('CCCN')
                send_datagram(packet, @server, @port)
            end

            d
        end

        def fullstat
            d = EM::DefaultDeferrable.new
            d.timeout(RESPONSE_TIMEOUT)

            if @state != :connected
                d.fail "Not connected"
            elsif @pending_query
                d.fail "Query currently pending"
            else
                @pending_query = d
                packet = [0xFE, 0xFD, 0x00, @id, @challenge, 0x00].pack('CCCNNN')
                send_datagram(packet, @server, @port)
            end

            d
        end

        def receive_data(data)
            case @state
            when :disconnected
                return
            when :handshake
                _,_,@challenge = data.unpack('CLZ*')
                @challenge = @challenge.to_i
                @state = :connected
                d = @pending_query
                @pending_query = nil
                d.succeed
            when :connected
                if @pending_query
                    q = Query.new(data)
                    d = @pending_query
                    @pending_query = nil
                    d.succeed q
                end
            end
        end

        def unbind
            if @pending_query
                @pending_query.fail 'Connection suddenly closed'
            end
        end
    end
end

module MinecraftPing
    def self.open(server, port='25565')
        EM.connect(server, port, Connection, server, port)
    end

    class Query
        attr_reader :proto_version
        attr_reader :version
        attr_reader :motd
        attr_reader :players
        attr_reader :max_players

        def initialize(data)
            id, string = data.unpack('Ca*')
            string.slice!(0..1)
            string.force_encoding('UTF-16BE').encode!('UTF-8')
            a = string.split("\x00")
            @proto_version = a[1]
            @version = a[2]
            @motd = a[3]
            @players = a[4]
            @max_players = a[5]
        end
    end

    class Connection < EM::Connection
        RESPONSE_TIMEOUT = 5

        def initialize(s, p)
            @server = s
            @port = p
        end

        def query
            d = EM::DefaultDeferrable.new
            d.timeout(RESPONSE_TIMEOUT)

            if @pending_query
                d.fail "Query already pending"
            else
                @pending_query = d
                # Query_1 is the 1.4-1.5 style ping. Majong Broke the fuck out
                # of the 1.6 server responses to this, forcing us to always
                # send the new, more complicated pings.
                query_1 = [0xFE, 0x01].pack('CC')
                query_2 = generate_new_query_part
                send_data(query_1 + query_2)
            end

            d
        end

        def receive_data(data)
            if d = @pending_query
                @pending_query = nil
                q = Query.new(data)
                d.succeed(q)
            end
        end

        def unbind
            if d = @pending_query
                @pending_query = nil
                d.fail 'Connection suddenly closed'
            end
        end

        def generate_new_query_part
            # Packet ID and constant string
            query = [0xFA, 0xB].pack('Cs>')
            query += ["MC|PingHost".encode('UTF-16BE')].pack('a*')

            # Compute length of query data
            query += [ 7 + 2*@server.length ].pack('s>')

            # Proto version
            query += [ 73 ].pack('C')

            # Length of hostname
            query += [ @server.length ].pack('s>')

            # Hostname
            query += [ @server.encode('UTF-16BE')].pack('a*')

            # Port
            query += [ @port.to_i ].pack('l>')

            query
        end
    end
end
