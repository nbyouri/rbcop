#!/usr/local/bin/ruby

require './cop'

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

  def initialize
    Context.set_vars
    @@context_priority = Hash.new do |prios|
      prios = Array.new
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

  def activate
    @@count += 1
    @@context_priority[self].push(@@count)
    self.dynamic_adapt
  end

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
end
