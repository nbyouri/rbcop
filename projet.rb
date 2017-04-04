require "test/unit"

class Context
  def initialize
    @@adaptations = Hash.new do |k,v|
      k[v] = Hash.new do |k2,v2|
        k2[v2] = Array.new
      end
    end
    @@count = 0
    @klass = nil
    @method = nil
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
    # If the hashmap is empty, start by adding base methods
    if @@adaptations.empty?
      klass.instance_methods(false).each do |name|
        meth = klass.instance_method(name)
        method_bound = meth.bind(klass.new)
        @@adaptations[klass][name].push(method_bound)
      end
    end

    # Execute the block
    @klass = klass
    @method = method
    @current_klass = klass.new
    val = instance_exec(&impl)
    block = Proc.new { val }
    p block.call
    @@adaptations[klass][method].push(block)
    self.dynamic_adapt
  end

  # Get to the previous adaptation
  def unadapt(klass, method)
    @@adaptations[klass][method].pop
    self.dynamic_adapt
  end

  # Call the next most prioritary method
  def proceed
    nbadapts = self.nbadapts(@klass, @method) - 1;
    previous_method = @@adaptations[@klass][@method][nbadapts]
    raise Exception, "Proceed on base method" if previous_method.nil?
    if previous_method.arity > 0
      previous_method.call(previous_method.parameters)
    else
      previous_method.call
    end
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

  def nbadapts(klass,method)
    @@adaptations[klass][method].size
  end

  def method_missing(method, *args)
      @klass.send(method, *args)
  end
end

class C
  def foo; 1; end
  def bar; 2; end
end

class D
  def foo; 1; end
  def bar; 2; end
end

class ContextTest < Test::Unit::TestCase
  # Use omit() until reset_cop_state is implemented
  def test_active
    omit()
    c = Context.new
    assert_equal(false, c.active?)
    c.activate
    active = c.active?
    c.deactivate
    assert_equal(true, active)
  end

  def test_adapt
    omit()
    c = Context.new
    c.adapt(C, :foo) { C.new.bar }
    c.activate
    assert_equal(2, C.new.foo)
    c.deactivate
    assert_equal(1, C.new.foo)
  end

  def test_adapt_arguments
    c = Context.new
    c.adapt(C, :foo) { |x| x }
    c.activate
    res = C.new.foo(5)
    c.deactivate
    assert_equal(5, res)
  end

  def test_unadapt
    omit()
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
    omit()
    c = Context.new
    c.activate
    c.adapt(C, :foo) { bar }
    c.adapt(C, :foo) { 3 }
    res = C.new.foo
    c.deactivate
    assert_equal(3, res)
  end

  def test_two_contexts
    omit()
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
    omit()
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
    omit()
    c, d = Context.new,	Context.new
    c.adapt(C, :foo) { 13 }
    d.adapt(C, :foo) { 6 + proceed() }
    c.activate
    d.activate
    res = C.new.foo
    c.deactivate
    d.deactivate
    assert_equal(19, res)
  end

  def test_nested_proceed
    omit()
    # TODO
  end
end
