require 'test/unit'
require 'chansey/irc-client/connection'
require 'socket'

class MockSingleSendServer < EventMachine::Connection
  def initialize(data)
    @data = data
  end

  def post_init
    send_data @data
  end
end

class ConnectionTest < Test::Unit::TestCase
  TEST_STRING = ":testnick!testuser@testaddress.com PRIVMSG #testchannel :Test Message"

  def test_pipeline
    assert_nothing_raised do
      EM.run do
        sig = EM.start_server "127.0.0.1", 0, MockSingleSendServer, TEST_STRING
        port = Socket.unpack_sockaddr_in(EM.get_sockname(sig)).first
        EM.connect "127.0.0.1", port, Chansey::IRC::Client::Connection
        EM.stop
      end
    end
  end
end
