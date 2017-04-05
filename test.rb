load 'projet.rb'

class C
  def foo; 1; end
  def bar; 2; end
end

class D
  def foo; 3; end
  def bar; 4; end
end

class AdaptTests < Test::Unit::TestCase
  # Use omit() until reset_cop_state is implemented
  def test_active
    c = Context.new
    assert_equal(false, c.active?)
    c.activate
    active = c.active?
    c.deactivate
    assert_equal(true, active)
  end

  def test_adapt
    c = Context.new
    c.adapt(C, :foo) { bar }
    c.activate
    assert_equal(2, C.new.foo)
    c.deactivate
    assert_equal(1, C.new.foo)
  end

  def test_unadapt
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
    c = Context.new
    c.activate
    c.adapt(C, :foo) { bar }
    c.adapt(C, :foo) { 3 }
    res = C.new.foo
    c.deactivate
    assert_equal(3, res)
  end
end

class ArgumentTests < Test::Unit::TestCase
  def test_adapt_arguments
    c = Context.new
    c.adapt(C, :foo) { |x,y| x + y }
    c.activate
    res = C.new.foo(1,2)
    c.deactivate
    assert_equal(3, res)
  end
end

class MultipleTests < Test::Unit::TestCase

  def test_two_contexts
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

  def test_two_classes
    c = Context.new
    c.adapt(C, :foo) { 13 }
    c.adapt(D, :foo) { 14 }
    c.activate
    res = C.new.foo + D.new.foo
    c.deactivate
    assert_equal(27, res)
  end

  def test_two_contexts_deactivation
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
end

class ProceedTests < Test::Unit::TestCase
  def test_proceed
    c =	Context.new
    c.activate
    c.adapt(C, :foo) { 3 }
    c.adapt(C, :foo) { bar + proceed }
    assert_equal(3, C.new.proceed)
    res = C.new.foo
    c.deactivate
    assert_equal(5, res)
  end

  # def test_proceed_arguments
  #   c = Context.new
  #   c.activate
  #   c.adapt(C, :foo) { |x| x }
  #   c.adapt(C, :foo) { proceed(2) }
  #   assert_equal(2, proceed(2))
  #   #res = C.new.foo(4)
  #   c.deactivate
  #   #assert_equal(5, res)
  # end

  # def test_nested_proceed
  #   omit()
  #   c, d = Context.new,	Context.new
  #   d.adapt(C, :foo) { 2 + proceed }
  #   assert_equal(1, C.new.proceed)
  #   c.adapt(C, :foo) { proceed + bar }
  #   assert_equal(3, C.new.proceed)
  #   c.activate
  #   d.activate
  #   res = C.new.foo
  #   c.deactivate
  #   d.deactivate
  #   assert_equal(3, res)
  # end
end