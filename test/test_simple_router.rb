require 'test/unit'

require 'chansey/simple_router'

class SimpleRouterTest < Test::Unit::TestCase
  TEST_ROUTE = "test/route"

  def setup
    @router = Chansey::SimpleRouter.new
  end

  def test_add_basic_registration
    assert_nothing_raised do
      r = @router.register(TEST_ROUTE) do
      end
    end

    assert_equal([TEST_ROUTE], @router.routes)
  end

  def test_basic_add_remove
    assert_nothing_raised do
      r = @router.register(TEST_ROUTE) do |t|
      end

      r.cancel
    end
  end

  def test_basic_add_and_receive
    pass = false

    r = @router.register(TEST_ROUTE) do
      pass = true
    end

    @router.route(TEST_ROUTE, nil)

    assert(pass)
  end

  def test_cancel
    pass = true

    r = @router.register(TEST_ROUTE) do
      pass = false
    end

    r.cancel

    @router.route(TEST_ROUTE, nil)

    assert(pass)
  end

  def test_gc
    (1..Chansey::SimpleRouter::DEFAULT_ROUTER_THRESHOLD).each do |i|
      r = @router.register("r#{i}") { }
      r.cancel
    end

    assert_equal(Chansey::SimpleRouter::DEFAULT_ROUTER_THRESHOLD, @router.routes.length)

    r = @router.register("0") { }
    r.cancel

    assert_equal(1, @router.routes.length)
  end
end
