#!/usr/local/bin/ruby

require './extra'
require "minitest/autorun"


class C
  def foo; 1; end
end

class ActivationsTest < Minitest::Test
  def test_activation
    reset_cop_state
    c = ExtraContext.new
    c.adapt(C, :foo) { 2 }
    c.activate
    c.activate
    c.activate
    c.deactivate
    c.deactivate
    assert_equal(2, C.new.foo)
  end

  def test_deactivation
    reset_cop_state
    c = ExtraContext.new
    c.adapt(C, :foo) { 2 }
    c.activate
    c.activate
    c.activate
    c.deactivate
    c.deactivate
    c.deactivate
    assert_equal(1, C.new.foo)
  end

  def test_priority
    reset_cop_state
    c,d, e = ExtraContext.new, ExtraContext.new, ExtraContext.new
    c.adapt(C, :foo) { 2 }
    d.adapt(C, :foo) { 3 }
    e.adapt(C, :foo) { 4 }
    c.activate
    d.activate
    e.activate
    d.activate
    c.activate
    d.deactivate
    d.deactivate
    e.deactivate
    assert_equal(3, C.new.foo)
  end
end
