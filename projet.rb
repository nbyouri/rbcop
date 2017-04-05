#!/usr/local/bin/ruby

class Context
  # Context + Implementation for a klass method
  class CI
    attr_accessor :ctx, :impl

    def initialize(ctx, impl)
      @ctx = ctx
      @impl = impl
    end
  end

  def initialize
    @@adaptations = Hash.new do |k,v|
      k[v] = Hash.new do |k2,v2|
        k2[v2] = Array.new
      end
    end
    @@count = 0
  end

  def active?
    @@count > 0
  end

  def activate
    @@count += 1
    self.dynamic_adapt
  end

  # Deactivate current context
  def deactivate
    if !active?; return end

    # Remove adaptations
    @@adaptations.each do |klass,methods|
      methods.each do |m,impls|
          impls.delete_if do |ci|
            ci.ctx == self
          end
          self.send_method(klass, m, impls.last.impl)
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
    self.push_adapt(klass, method, self, impl)

    # Apply
    self.dynamic_adapt
  end

  # Get to the previous adaptation
  # XXX only unadapt on self?
  def unadapt(klass, method)
    @@adaptations[klass][method].pop
    self.dynamic_adapt
  end

  # Call the next most prioritary method
  def proceed(klass, method)
    previous_method = @@adaptations[klass][method].last.impl
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

    # Define most prioritary implementation of context for each method
    @@adaptations.each do |klass, methods|
      methods.each do |m,impls|
        cimpls = impls.select do |ci|
          ci.ctx == self
        end
        # Install the base methods if no other context is available
        cimpls = impls if cimpls.empty?
        self.send_method(klass, m, cimpls.last.impl)
      end
    end
  end

  def add_base_methods(klass)
    if @@adaptations[klass].empty?
      klass.instance_methods(false).each do |name|
        # Ignore leftover proceed method
        next if name.to_s == "proceed"
        meth = klass.instance_method(name)
        method_bound = meth.bind(klass.new)
        self.push_adapt(klass, name, nil, method_bound.to_proc)
      end
    end
  end

  # Push a new adaptation
  def push_adapt(klass, method, ctx, impl)
    ci = CI.new(ctx, impl)
    @@adaptations[klass][method].push(ci)
  end
end
