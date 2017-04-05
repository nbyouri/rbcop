#!/usr/local/bin/ruby

require "test/unit"

class Context
  def initialize
    @@adaptations = Hash.new do |k,v|
      k[v] = Hash.new do |k2,v2|
        k2[v2] = Array.new
      end
    end
    @@count = 0
  end

  # Returns whether the method is active
  def active?
    @@count > 0
  end
  # For each of the adaptations hashmap, activate the most recent adaptation
  def activate
    @@count += 1
    self.dynamic_adapt
  end

  # Go back to the base methods
  def deactivate
    if !active?; return end

    # Remove adaptations
    @@adaptations.each do |klass,methods|
      methods.each do |m,impls|
          impls = [impls.first]
          self.send_method(klass, m, impls.last)
      end
    end
  end

  # Add a method to the class
  # adaptations are stored in a hashmap containing a stack of adaptations
  # for each method
  def adapt(klass, method, &impl)
    # If this is the first adapt, start by adding base methods
    self.add_base_methods(klass)

    # Define a proceed method
    self.send_method(klass, :proceed, proceed(klass, method))

    # Add the adaptation
    @@adaptations[klass][method].push(impl)
    self.dynamic_adapt
  end

  # Get to the previous adaptation
  def unadapt(klass, method)
    @@adaptations[klass][method].pop
    self.dynamic_adapt
  end

  # Call the next most prioritary method
  def proceed(klass, method)
    previous_method = @@adaptations[klass][method].last
    raise Exception, "Proceed on base method" if previous_method.nil?
    previous_method
  end

  # Define a method in class
  def send_method(klass, method, impl)
    klass.send(:define_method, method, impl)
  end

  # Define an adaptation if the context is active
  def dynamic_adapt
    if !active?; return end

    # Define most prioritary implementation for each method
    @@adaptations.each do |klass, methods|
      methods.each do |m,impls|
        self.send_method(klass, m, impls.last)
      end
    end
  end

  # Returns amount of implementations in store for a method
  def nbadapts(klass,method)
    @@adaptations[klass][method].size
  end

  # Add a klass methods
  def add_base_methods(klass)
    if @@adaptations[klass].empty?
      klass.instance_methods(false).each do |name|
        next if name.to_s == "proceed"
        meth = klass.instance_method(name)
        method_bound = meth.bind(klass.new)
        @@adaptations[klass][name].push(method_bound.to_proc)
      end
    end
  end
end

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
end

class ProceedTests < Test::Unit::TestCase
  def test_proceed
    c =	Context.new
    c.adapt(C, :foo) { 3 }
    c.adapt(C, :foo) { 2 + proceed }
    assert_equal(3, C.new.proceed)
    c.activate
    res = C.new.foo
    c.deactivate
    assert_equal(5, res)
  end

  def test_proceed_arguments
    omit()
    c = Context.new
    c.adapt(C, :foo) { |x| x+proceed() }
    res = C.new.foo(4)
    c.deactivate
    assert_equal(5, res)
  end

  def test_nested_proceed
    omit()
    c, d = Context.new,	Context.new
    d.adapt(C, :foo) { 2 + proceed }
    assert_equal(1, C.new.proceed)
    c.adapt(C, :foo) { proceed + bar }
    assert_equal(3, C.new.proceed)
    c.activate
    d.activate
    res = C.new.foo
    c.deactivate
    d.deactivate
    assert_equal(3, res)
  end
end
