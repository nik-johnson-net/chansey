require 'socket'
require 'test/unit'

require 'chansey/modules/irc/connection'

class MockSingleSendServer < EventMachine::Connection
  def initialize(data)
    @data = data
  end

  def post_init
    send_data @data
  end
end

class ConnectionTest < Test::Unit::TestCase
  TEST_STRING = ":testnick!testuser@testaddress.com PRIVMSG #testchannel :Test Message\r\n"

  def test_registration
    EM.run do
      handler = Class.new do
        include Chansey::Modules::Irc::Handler
        def initialize(&block)
          @block = block
        end

        def registered(connection)
          @block.call
          EM.stop
        end
      end

      sig = EM.start_server "127.0.0.1", 0, MockSingleSendServer, TEST_STRING
      port = Socket.unpack_sockaddr_in(EM.get_sockname(sig)).first
      EM.connect("127.0.0.1", port, Chansey::Modules::Irc::Connection, [handler.new { assert(true) }])
      EM.add_timer(5) { assert(false, "Failed to receive message"); EM.stop }
    end
  end
end
