require 'test/unit'
require 'chansey/irc_client/irc_decoder'

class IrcDecoderTest < Test::Unit::TestCase
  def setup
    @decoder = Chansey::IrcClient::IrcDecoder.new
  end

  def test_decode_privmsg
    string = ":nick!user@test.com PRIVMSG #testchan :Hello, World!"
    result = @decoder.map(string)

    assert_kind_of Hash, result
    assert_equal 'nick', result[:nick]
    assert_equal 'user', result[:user]
    assert_equal 'test.com', result[:host]
    assert_equal :privmsg, result[:command]
    assert_equal ['#testchan'], result[:middle]
    assert_equal 'Hello, World!', result[:trailing]
  end

  def test_double_user
    string = ":nick!user!user@test.com PRIVMSG #channel :hi"
    result = @decoder.map(string)

    assert_equal nil, result
  end

  def test_double_host
    string = ":nick!user@test.com@test.com PRIVMSG #channel :hi"
    result = @decoder.map(string)

    assert_equal nil, result
  end

  def test_too_many_middles
    string = ":nick!user@test.com PRIVMSG c1 c2 c3 c4 c5 c6 c7 c8 c9 c10 c11 c12 c13 c14 c15 :hi"
    result = @decoder.map(string)

    assert_equal nil, result
  end
end
