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

class MinecraftQueryRequest
  include EM::Deferrable

  DEFAULT_MINECRAFT_PORT = 25565
  PORT_MIN = 0
  PORT_MAX = 65535

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

      p target

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

  def query_server(addr, port)
    MinecraftPing.new(addr, port).
      callback do |*args|
        #TODO Handle success
        succeed args
      end.
      errback do |*args|
        #TODO Handle failure
        fail args
      end
  end
end

@router.register 'irc/command/mc' do |cmd, ctx|
  mqr = MinecraftQueryRequest.new(cmd.arg.split.first)
  mqr.callback { |a| cmd.reply("Success: #{a.inspect}") }
  mqr.errback { |a| cmd.reply("Failure: #{a.inspect}") }
end
