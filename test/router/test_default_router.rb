require 'test/unit'

require 'chansey/router/default_router'

class DefaultRouterTest < Test::Unit::TestCase
  TEST_ROUTE = "test/route"

  def setup
    @router = Chansey::Router::DefaultRouter.new
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

    @router.route(TEST_ROUTE)

    assert(pass)
  end

  def test_cancel
    pass = true

    r = @router.register(TEST_ROUTE) do
      pass = false
    end

    r.cancel

    @router.route(TEST_ROUTE)

    assert(pass)
  end

  def test_gc
    (1..Chansey::Router::DefaultRouter::DEFAULT_ROUTER_THRESHOLD).each do |i|
      r = @router.register("r#{i}") { }
      r.cancel
    end

    assert_equal(Chansey::Router::DefaultRouter::DEFAULT_ROUTER_THRESHOLD, @router.routes.length)

    r = @router.register("50") { }
    r.cancel

    assert_equal(0, @router.routes.length)
  end
end
