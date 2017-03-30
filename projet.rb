require "minitest/autorun"

class Context
  def initialize
    @@adaptations = Hash.new {|h,k| h[k] = Hash.new {|h2,k2| h2[h2] = []}}
    @@count = 0
  end

  # Returns whether the method is active
  def active?
    @@count == 0
  end
  # For each of the adaptations hashmap, activate the most recent adaptation
  def activate
    @@adaptations.each {|key, value|
      key.send(:define_method, method, &impl)
    }
  end
  def deactivate; end
  # Add a method to the class
  # adaptations are stored in a hashmap containing a stack of adaptations
  # for each method
  def adapt(klass, method, &impl)
    @@adaptations[klass][method].push(impl)
  end

  # Get to the previous adaptation
  def unadapt(klass, method)

  end
end

class C
  def foo; 1; end
  def bar; 2; end
end

class Test < Minitest::Test
  def test_adapt
    c = Context.new
    c.adapt(C, :foo) { C.new.bar }
    assert_equal(2, C.new.foo)
    c.adapt(C, :foo) { |x| x }
    assert_equal(5, C.new.foo(5))
  end

  def test_unadapt
    c = Context.new
    c.adapt(C, :foo) { C.new.bar }
    c.unadapt(C, :foo)
    assert_equal(1, C.new.foo)
  end
end
