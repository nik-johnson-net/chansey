require 'logger'
require 'socket'
require 'test/unit'

require 'chansey/irc_client/connection'

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

  def test_pipeline
    EM.run do
      sig = EM.start_server "127.0.0.1", 0, MockSingleSendServer, TEST_STRING
      port = Socket.unpack_sockaddr_in(EM.get_sockname(sig)).first
      EM.connect("127.0.0.1", port, Chansey::IrcClient::Connection, {}, Logger.new(nil)) do |c|
        c.handler  = lambda do |d,conn|
          assert_equal({
            :nick => 'testnick',
            :user => 'testuser',
            :host => 'testaddress.com',
            :command => :privmsg,
            :middle => ['#testchannel'],
            :trailing => 'Test Message',
          }, d)
          EM.stop
        end
      end

      EM.add_timer(5) { assert(false, "Failed to receive message"); EM.stop }
    end
  end
end
