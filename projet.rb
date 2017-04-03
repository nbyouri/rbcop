require "test/unit"

class Context
  def initialize
    @adaptations = Hash.new { |k,v|
      k[v] = Hash.new { |k2,v2|
        k2[v2] = []
      }
    }
    @count = 0
  end

  # Returns whether the method is active
  def active?
    @count > 0
  end
  # For each of the adaptations hashmap, activate the most recent adaptation
  def activate
    @adaptations.each { |klass, methods|
      methods.each {|m,impls|
        send_method(klass, m, impls.last)
      }
    }
    @count += 1
  end

  # Go back to the base methods
  def deactivate
    if (!active?); return; end

    # Remove adaptations
    @adaptations.each {|klass,methods|
      methods.each {|m,impls|
          impls = [impls.first]
          send_method(klass, m, impls.last)
      }
    }

  end

  # Add a method to the class
  # adaptations are stored in a hashmap containing a stack of adaptations
  # for each method
  def adapt(klass, method, &impl)
    # If the hashmap is empty, start by adding base methods
    if (@adaptations.empty?)
      klass.instance_methods(false).each do |name|
        meth = klass.instance_method(name)
        method_bound = meth.bind(klass.new)
        @adaptations[klass][name].push(method_bound)
      end
    end

    @adaptations[klass][method].push(impl)
  end

  # Get to the previous adaptation
  def unadapt(klass, method)
    @adaptations[klass][method].pop
  end

  # Call the next most prioritary method
  def proceed
  end

  # Utils
  def send_method(klass, method, impl)
    klass.send(:define_method, method, impl)
  end
end

class C
  def foo; 1; end
  def bar; 2; end
end

class ContextTest < Test::Unit::TestCase
  def test_active
    c = Context.new
    assert_equal(false, c.active?)
    c.activate
    assert_equal(true, c.active?)
    c.deactivate
  end

  def test_adapt
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
    assert_equal(5, C.new.foo(5))
    c.deactivate
  end

  def test_unadapt
    c = Context.new
    c.adapt(C, :foo) { C.new.bar }
    c.activate
    c.unadapt(C, :foo)
    c.activate
    assert_equal(1, C.new.foo)
    c.deactivate
  end
end
