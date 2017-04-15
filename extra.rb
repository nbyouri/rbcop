#!/usr/local/bin/ruby

require './cop'
require "test/unit"

class ExtraContext < Context
  # Add priority
  class CIP < CI
    attr_accessor :prio

    def initialize(ctx, impl, prio)
      @ctx = ctx
      @impl = impl
      @prio = prio
    end
  end

  # Add a method to the class
  # adaptations are stored in a hashmap containing a stack of adaptations
  # for each method
  def adapt(klass, method, &impl)
    # If this is the first adapt, start by adding base methods
    self.add_base_methods(klass)

    # Define a proceed method
    latest = self.proceed(klass, method)
    # XXX (´･_･`) hack
    hack = impl.to_source(:ignore_nested => true).gsub(/proceed/, latest.to_s)

    # Add the adaptation
    prio = @@adaptations[klass][method].size
    self.push_adapt(klass, method, CIP.new(self, eval(hack), prio))

    # Apply
    self.dynamic_adapt
  end

  # Deactivate current context
  def deactivate
    if !active?; return end

    # Remove adaptations
    @@adaptations.each do |klass,methods|
      methods.each do |m,impls|
          impls.delete_if do |cip|
            cip.ctx == self && cip.prio == @@count
          end
          self.send_method(klass, m, impls.last.impl)
      end
    end
    @@count -= 1
  end

  # Debug
  def self.print_adaptations
    @@adaptations.each do |klass,methods|
      methods.each do |m,impls|
        impls.each do |cip|
          if defined? cip.prio
            p "#{m} -- #{cip.prio}"
          end
        end
      end
    end
  end
end

class C
  def foo; 1; end
end

class ActivationsTest < Test::Unit::TestCase
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

  def test_priority2
    reset_cop_state
    a,b,c = ExtraContext.new, ExtraContext.new, ExtraContext.new
    a.adapt(C, :foo) { 2 }
    b.adapt(C, :foo) { 3 }
    c.adapt(C, :foo) { 4 }
    c.activate
    b.activate
    a.activate
    ExtraContext.print_adaptations
  end
end
