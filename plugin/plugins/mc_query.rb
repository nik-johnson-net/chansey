# encoding: utf-8

require 'timeout'

class MCQuery < Chansey::Plugin
    include Chansey::Plugin::IRCPlugin
    events 'irc.privmsg'

    def init
        @command_key = '.'
        command("mc", {:priv => true}, &method(:query_server))
    end

    def query_server(event)
        # Get arguments
        params = event['data']['msg']['params'].split[1..-1]

        # Set reply destination
        if event['data']['msg']['middle'].first == 'chansey' 
            destination = event['data']['msg']['nick']
        else
            destination = event['data']['msg']['middle'].first
        end

        # Verify params are present
        unless params.length.between?(1,2)
            privmsg(event['data']['network'],
                    destination,
                    "Usage: <hostname> [port]")
            return
        end

        # Do a ping query to grab most information
        begin
            results = mc_query(*params)
        rescue => e
            @log.warn "Caught#{e.exception}: #{e.backtrace.join("\n")}"
            privmsg(event['data']['network'],
                    event['data']['msg']['middle'][0],
                    "Error querying server (#{e.exception})")
            return
        end

        # If we couldn't grab ping information quit
        if results.nil?
            privmsg(event['data']['network'],
                    event['data']['msg']['middle'][0],
                    "Could not query server (maybe it's offline?)")
            return
        end

        # Do a UT3 query to grab player list. If it fails, fail silently
        data = {}
        begin
            qt3 = UT3Query.new(@log, *params) 
            data = qt3.fullstat
        rescue Timeout::Error
        rescue => e
            @log.warn "Caught#{e.exception}: #{e.backtrace.join("\n")}"
        end

        result_string = "#{params[0]}: Players: %d/%d - Version: %s - MOTD: %s" %
            [ results[4], results[5], results[2], results[3].mc_to_irc_colors ]
        result_string += " - Players: #{data[:players].join(', ')}" if data[:players]
        privmsg(event['data']['network'],
                destination,
                result_string)
    end
    
    private
    # Uses the Server List query packet
    def mc_query(hostname, port=25565)
        # TCPSocket wants port as an integer
        if port.class == String
            port = port.to_i
        end

        # Wrap the connection in a shorter timeout
        @log.debug "Querying #{hostname}:#{port}..."
        s = nil
        begin
            Timeout::timeout(3) do
                s = TCPSocket.new hostname, port
            end
        rescue Timeout::Error
            return nil
        end

        query = [0xFE, 0x01].pack('CC')
        s.send(query, 0)
        data = s.readpartial(1024)
        id, string = data.unpack('Ca*')
        string.slice!(0..1)
        string.force_encoding('UTF-16BE').encode!('UTF-8')

        @log.debug "Query Result: #{string.split("\x00").map {|x| x.inspect }}"
        string.split("\x00")
    end
end

# Minecraft optionally supports the UT3 query protocol
# This provides player information as well; We'll try it and see what happens
class UT3Query
    @@randgen = Random.new(1337)

    def initialize(log, server, port=25565)
        port = port.to_i if port.class != Fixnum
        @log = log

        # Create UDP Socket
        @sock = UDPSocket.new
        @sock.connect(server, port)
        @id = @@randgen.bytes(4).unpack('L')[0] & 0x0F0F0F0F
        @log.debug "Session id: #{@id} - #{[@id].pack('N').inspect}"
        handshake
    end

    def handshake
        packet = [0xFE, 0xFD, 0x09, @id].pack('CCCN')
        response = nil
        Timeout::timeout(1) do
            @sock.send packet, 0
            response = @sock.readpartial(1024)
        end

        _,_,@challenge = response.unpack('CLZ*')
        @challenge = @challenge.to_i
    end

    def basicstat
    end

    def fullstat
        request = [0xFE, 0xFD, 0x00, @id, @challenge, 0x00].pack('CCCNNN')
        response = nil

        Timeout::timeout(1) do
            @sock.send request, 0
            response = @sock.readpartial(4096)
        end

        response.slice!(0..15)
        info, _, players = response.partition("\x00\x01player_\x00\x00")
        data = Hash[*info.split("\x00")]
        players = players.split("\x00")
        data[:players] = players
        @log.debug "data: #{ data.inspect }"
        return data
    end
end

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

class String
    def mc_to_irc_colors
        newstr = gsub(/§(.)/) do |code|
            MC_IRC_MAP[$1]
        end
        newstr.insert(-1, "\x0F\x03")
        newstr
    end
end
