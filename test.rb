#!/usr/local/bin/ruby

load 'cop.rb'
require "test/unit"

class C
  def foo; 1; end
  def bar; 2; end
end

class D
  def foo; 3; end
  def bar; 4; end
end

module M
  def foo; 5; end
end

class T
  include M
end

class X; end

class AdaptTests < Test::Unit::TestCase
  def test_active
    reset_cop_state
    c = Context.new
    assert_equal(false, c.active?)
    c.activate
    active = c.active?
    c.deactivate
    assert_equal(true, active)
  end

  def test_adapt
    reset_cop_state
    c = Context.new
    c.adapt(C, :foo) { bar }
    c.activate
    assert_equal(2, C.new.foo)
    c.deactivate
    assert_equal(1, C.new.foo)
  end

  def test_unadapt
    reset_cop_state
    c = Context.new
    c.adapt(C, :foo) { bar }
    c.activate
    c.unadapt(C, :foo)
    c.activate
    res = C.new.foo
    c.deactivate
    assert_equal(1, res)
  end

  def test_onthefly
    reset_cop_state
    c = Context.new
    c.activate
    c.adapt(C, :foo) { bar }
    c.adapt(C, :foo) { 3 }
    res = C.new.foo
    c.deactivate
    assert_equal(3, res)
  end

  def test_unadapt_self
    reset_cop_state
    c,d = Context.new, Context.new
    c.activate
    d.activate
    c.adapt(C, :foo) { 3 }
    c.adapt(C, :foo) { 4 }
    d.adapt(C, :foo) { 5 }
    d.unadapt(C, :foo)
    res = C.new.foo
    c.deactivate
    d.deactivate
    assert_equal(4, res)
  end

  def test_unadapt_self_2
    reset_cop_state
    c,d = Context.new, Context.new
    c.activate
    d.activate
    c.adapt(C, :foo) { 3 }
    c.adapt(C, :foo) { 4 }
    d.adapt(C, :foo) { 5 }
    c.unadapt(C, :foo)
    d.unadapt(C, :foo)
    res = C.new.foo
    c.deactivate
    d.deactivate
    assert_equal(3, res)
  end

  def test_unadapt_self_3
    reset_cop_state
    c,d = Context.new, Context.new
    c.activate
    d.activate
    c.adapt(C, :foo) { 3 }
    c.adapt(C, :foo) { 4 }
    d.adapt(C, :foo) { 5 }
    c.unadapt(C, :foo)
    res = C.new.foo
    c.deactivate
    d.deactivate
    assert_equal(5, res)
  end
end

class ArgumentTests < Test::Unit::TestCase
  def test_adapt_arguments
    reset_cop_state
    c = Context.new
    c.adapt(C, :foo) { |x,y| x + y }
    c.activate
    res = C.new.foo(1,2)
    c.deactivate
    assert_equal(3, res)
  end

  def test_arguments_nested_block
    reset_cop_state
    c = Context.new
    c.activate
    c.adapt(C, :foo) { |x| s = ""; x.each {|i| s << i.to_s }; s}
    assert_equal("123", C.new.foo([1,2,3]))
    Context.reset_cop_state
  end

  def test_arguments_optional
    reset_cop_state
    c = Context.new
    c.activate
    c.adapt(C, :foo) { |x = 2| x }
    assert_equal(2, C.new.foo)
    Context.reset_cop_state
  end

  def test_arguments_array_decomposition
    reset_cop_state
    c = Context.new
    c.activate
    c.adapt(C, :foo) { |x,*y| y }
    res = C.new.foo(1,2,3)
    Context.reset_cop_state
    assert_equal([2,3], res)
  end

  def test_arguments_block
    reset_cop_state
    c = Context.new
    c.activate
    c.adapt(C, :foo) { |&block| lambda { block } }
    res = C.new.foo { 1 }.call.call
    Context.reset_cop_state
    assert_equal(1, res)
  end
end

class MultipleTests < Test::Unit::TestCase
  def test_two_contexts
    reset_cop_state
    c, d = Context.new, Context.new
    c.adapt(C, :foo) { 91 }
    d.adapt(C, :foo) { 92 }
    c.activate
    d.activate
    d.unadapt(C, :foo)
    res = C.new.foo
    c.deactivate
    d.deactivate
    assert_equal(91, res)
  end

  def test_activation_priority
    reset_cop_state
    c,d = Context.new, Context.new
    d.adapt(C, :foo) { 13 }
    c.adapt(C, :foo) { 14 }
    d.activate
    c.activate
    d.activate
    res = C.new.foo
    c.deactivate
    d.deactivate
    assert_equal(13, res)
  end

  def test_two_contexts_deactivation
    reset_cop_state
    c,d = Context.new, Context.new
    c.activate
    d.activate
    c.adapt(C, :foo) { 1337 }
    d.adapt(C, :foo) { 8888 }
    d.deactivate
    res = C.new.foo
    c.deactivate
    assert_equal(1337, res)
  end

  def test_deactivation_active
    reset_cop_state
    c = Context.new
    c.adapt(C, :foo) { 3 }
    c.activate
    c.activate
    c.deactivate
    assert_equal(false, c.active?)
    reset_cop_state
  end
end

class ProceedTests < Test::Unit::TestCase
  def test_proceed
    reset_cop_state
    c =	Context.new
    c.activate
    c.adapt(C, :foo) { 3 }
    c.adapt(C, :foo) { bar + proceed() }
    res = C.new.foo
    c.deactivate
    assert_equal(5, res)
  end

  def test_proceed_arguments
    reset_cop_state
    c = Context.new
    c.activate
    c.adapt(C, :foo) { |x| x }
    c.adapt(C, :foo) { |x,y| x + y * proceed(2) }
    res = C.new.foo(3,2)
    c.deactivate
    assert_equal(7, res)
  end

  def test_nested_proceed
    reset_cop_state
    c = Context.new
    c.activate
    c.adapt(C, :foo) { 2 + proceed }
    c.adapt(C, :foo) { proceed + bar + proceed }
    res = C.new.foo
    c.deactivate
    assert_equal(8, res)
  end

  def test_proceed_unadapt
    reset_cop_state
    c = Context.new
    c.activate
    c.adapt(C, :foo) { 5 }
    c.adapt(C, :foo) { 6 }
    c.unadapt(C, :foo)
    c.adapt(C, :foo) { proceed }
    res = C.new.foo
    c.deactivate
    assert_equal(5, res)
  end
end

class ResetTests2 < Test::Unit::TestCase
  def test_reset
    reset_cop_state
    assert_equal(1, C.new.foo)
    c = Context.new
    c.activate
    c.adapt(C, :foo) { 3 }
    c.unadapt(C, :foo)
    assert_equal(1, C.new.foo)
    c.deactivate
  end
end

class ModuleTests < Test::Unit::TestCase
  def test_module
    reset_cop_state
    c = Context.new
    c.activate
    c.adapt(M, :foo) { 1  }
    assert_equal(1, T.new.foo)
    c.deactivate
  end
end
