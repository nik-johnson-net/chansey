require 'test/unit'
require 'chansey/irc_client/line_decoder'

class LineDecoderTest < Test::Unit::TestCase
  def setup
    @decoder = Chansey::IrcClient::LineDecoder.new
  end

  def test_return_type
    result = @decoder.map("")

    assert_kind_of Array, result
  end

  def test_splits_crnl
    string = "Line1\r\nLine2\r\n"
    result = @decoder.map(string)

    assert_equal "Line1", result[0]
    assert_equal "Line2", result[1]
  end

  def test_splits_nl
    string = "Line1\nLine2\n"
    result = @decoder.map(string)

    assert_equal "Line1", result[0]
    assert_equal "Line2", result[1]
  end

  def test_buffer
    result = @decoder.map("Line1\nLin")
    assert_equal "Line1", result[0]
    assert_equal nil, result[1]

    result = @decoder.map("e2\n")
    assert_equal "Line2", result[0]

    result = @decoder.map("Line3\n")
    assert_equal "Line3", result[0]
  end

  def test_bad_args
    assert_raises(ArgumentError) do
      @decoder.map(["Arraylulz\n"])
    end
  end
end
