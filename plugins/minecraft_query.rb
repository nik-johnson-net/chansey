require 'chansey/util/deferrable'

# Hack up EM's Async DNS class to do SRV
class SRVRequest < EM::DNS::Request
  def receive_answer(msg)
    addrs = []
    msg.each_answer do |name,ttl,data|
      if data.kind_of?(Resolv::DNS::Resource::IN::SRV)
        addrs << data
      end
    end

    if addrs.empty?
      fail "rcode=#{msg.rcode}"
    else
      succeed addrs
    end
  end

  private
  def packet
    msg = Resolv::DNS::Message.new
    msg.id = id
    msg.rd = 1
    msg.add_question @hostname, Resolv::DNS::Resource::IN::SRV
    msg
  end
end

class UT3Query
  include EM::Deferrable

  FullStat = Struct.new(:info, :players)

  class Connection < EM::Connection
    RANDOM = Random.new

    def initialize(server, port, deferrable)
      @server = server
      @port   = port
      @id     = RANDOM.bytes(4).unpack('L').first & 0x0F0F0F0F
      @state  = :disconnected
      @defer  = deferrable

      handshake
    end

    def receive_data(data)
      case @state
      when :disconnected
        raise "Received packet while disconnected"
      when :handshake
        _, _, @challenge = data.unpack('CLZ*')
        @challenge = @challenge.to_i
        @state = :connected

        full_stat
      when :connected
        # TODO ID verification
        data.slice!(0..15)
        info, _, players = data.partition("\x00\x01player_\x00\x00")

        info = Hash[*info.split("\x00")]
        players = players.split("\x00")

        @defer.succeed FullStat.new(info, players)

        close_connection
      end
    end

    private
    def handshake
      @state = :handshake
      packet = [0xFE, 0xFD, 0x09, @id].pack('CCCN')
      send_datagram(packet, @server, @port)
    end

    def full_stat
      packet = [0xFE, 0xFD, 0x00, @id, @challenge, 0x00].pack('CCCNNN')
      send_datagram(packet, @server, @port)
    end
  end

  def initialize(server, port, timeout=2)
    self.timeout(timeout)
    EM.open_datagram_socket('0.0.0.0', '0', Connection, server, port, self)
  end
end

class MinecraftQueryRequest
  include EM::Deferrable

  DEFAULT_MINECRAFT_PORT    = 25565
  PING_RESPONSE_TEMPLATE    = "%{server}: Players: %{players}/%{max_players} - Version: %{version} - MOTD: %{motd}"
  PLAYERS_RESPONSE_TEMPLATE = "%{server}: Players online: %{player_list}"
  PORT_MIN                  = 0
  PORT_MAX                  = 65535

  class MinecraftResolver
    include EM::Deferrable

    Target = Struct.new(:hostname, :port)

    SRV_RECORD_FORMAT = %q|_minecraft._tcp.%{hostname}|

    def initialize(hostname, port)
      # Calculate the DNS Record path for a SRV Record
      srv_record_string = SRV_RECORD_FORMAT % { :hostname => hostname }

      # Attempt to resolve SRV records
      srv_deferrable = SRVRequest.new(EM::DNS::Resolver.socket, srv_record_string)
      srv_deferrable.callback do |addrs|

        # If so, sort according to priority and convert to Targets
        targets = addrs.
          sort { |a,b| a.priority <=> b.priority }.
          map { |r| Target.new(r.target, r.port) }

        # Then try to resolve them all
        resolve(targets)
      end.errback do |reason|

        # Otherwise do a normal resolve
        resolve([Target.new(hostname, port)])
      end
    end

    # Recursively resolve
    def resolve(targets)
      target = targets.shift

      # If no more hosts to try then fail
      if target.nil?
        fail
        return
      end

      # Async resolve the next host
      dns_deferrable = EM::DNS::Resolver.resolve(target.hostname)
      dns_deferrable.callback do |addr|
        succeed addr.first, target.port
      end.errback do |reason|
        resolve(targets)
      end
    end
  end

  class MinecraftPing
    include EM::Deferrable

    MinecraftPingResponse = Struct.new(:proto_proto, :version, :motd, :players, :max_players)

    class Connection < EM::Connection
      def initialize(server, port, deferrable)
        @server = server
        @port = port
        @deferrable = deferrable

        query_1 = [0xFE, 0x01].pack('CC')
        query_2 = generate_newage_query
        send_data(query_1 + query_2)
      end

      def receive_data(data)
        id, string = data.unpack('Ca*')
        string.slice!(0..1)
        string.force_encoding('UTF-16BE').encode!('UTF-8')
        response = string.split("\x00")

        @deferrable.succeed MinecraftPingResponse.new(
          response[1],
          response[2],
          response[3],
          response[4],
          response[5]
        )

        close_connection
      end

      def unbind
        @deferrable.fail "remote host suddenly closed the connection"
      end

      def generate_newage_query
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

    def initialize(addr, port)
      EM.connect(addr, port, Connection, addr, port, self)
    end
  end

  def initialize(hostname, port=DEFAULT_MINECRAFT_PORT)
    if hostname.nil?
      raise ArgumentError, "Error no hostname given"
    end

    if !port.is_a?(Integer) || !(PORT_MIN..PORT_MAX).include?(port)
      raise ArgumentError, "Port must be an integer between #{PORT_MIN} and #{PORT_MAX}"
    end

    @hostname = hostname
    @port     = port

    mr = MinecraftResolver.new(hostname, port)
    mr.callback { |addr, port| query_server(addr, port) }
    mr.errback { |r| fail "could not resolve hostname #{hostname}" }
  end

  private
  def query_server(addr, port)
    ping_deferrable = MinecraftPing.new(addr, port)
    ut3_deferrable = UT3Query.new(addr, port)

    deferrable = Chansey::Util::DeferrableJoin.new(ping_deferrable, ut3_deferrable)
    deferrable.callback do |mcping, ut3ping|
      receive_responses(mcping, ut3ping)
    end.errback do |mcping, ut3ping|
      fail mcping.args.first
    end
  end

  def receive_responses(mcping, ut3ping)
    # MCPing is a required response. Fail without it.
    if mcping.is_a? Chansey::Util::DeferrableJoin::FailedDeferrable
      fail mcping.args.first
      return
    else
      mcping = mcping.args.first
    end

    # UT3 is optional, simply set to nil if unavailable
    if ut3ping.is_a? Chansey::Util::DeferrableJoin::FailedDeferrable
      ut3ping = nil
    else
      ut3ping = ut3ping.args.first
    end

    # Render responses
    succeed render(mcping, ut3ping)
  end

  def render(mcping, ut3ping)
    ping_response = PING_RESPONSE_TEMPLATE % {
      :server       => "#{@hostname}#{@port if @port != DEFAULT_MINECRAFT_PORT}",
      :players      => mcping.players,
      :max_players  => mcping.max_players,
      :version      => mcping.version,
      :motd         => mcping.motd,
    }

    ut3_response = ut3ping ? " -- #{ut3ping.players.join(', ')}" : ''

    ping_response + ut3_response
  end
end

@router.register 'irc/command/mc' do |cmd, ctx|
  mqr = MinecraftQueryRequest.new(cmd.arg.split.first)
  mqr.callback { |response| cmd.reply(response) }
  mqr.errback { |a| cmd.reply("Error: #{a}") }
end
