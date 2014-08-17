require 'test/unit'

require 'chansey/core'
require 'chansey/module'

class MockRouter
end

class MockMod < Chansey::Module
  def initialize(core)
    super
  end
end

class CoreTest < Test::Unit::TestCase
  def test_insert_module
    EM.run do
      core = Chansey::Core.new({}, MockRouter.new)
      mod = MockMod.new(core)
      ret = core.insert_module(mod)

      assert_equal(mod, ret)
      EM.stop
    end
  end
end
