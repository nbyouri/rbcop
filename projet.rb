require 'sourcify'

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
    Context.set_vars
  end

  def self.set_vars
    @@adaptations = Hash.new do |klass,methods|
      klass[methods] = Hash.new do |method,impls|
        method[impls] = Array.new
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
    latest = self.proceed(klass, method)
    # XXX hack
    hack = impl.to_source(:ignore_nested => true).gsub(/proceed/, latest.to_s)

    # Add the adaptation
    self.push_adapt(klass, method, self, eval(hack))

    # Apply
    self.dynamic_adapt
  end

  # Get to the previous adaptation
  def unadapt(klass, method)
    self.pop_adapt(klass, method, self)
    self.dynamic_adapt(false)
  end

  # Define the next most prioritary method
  def proceed(klass, method)
    previous_method = @@adaptations[klass][method].last.impl
    count = @@adaptations[klass][method].size
    raise Exception, "Proceed on base method" if previous_method.nil?
    latest = ["proceed",  method.to_s, count.to_s].join('_').to_sym
    self.send_method(klass, latest, previous_method)
    latest
  end

  # Define a method in class
  def send_method(klass, method, impl)
    klass.send(:define_method, method, impl)
  end

  # Define an adaptation if the context is active
  def dynamic_adapt(activate_self = true)
    if !active?; return end

    # Define most prioritary implementation of context for each method
    @@adaptations.each do |klass, methods|
      methods.each do |m,impls|
        cimpls = impls.select do |ci|
          ci.ctx == self if activate_self
        end
        # Define the base methods if no other context is available
        cimpls = impls if cimpls.empty?
        self.send_method(klass, m, cimpls.last.impl)
      end
    end
  end

  def add_base_methods(klass)
    if @@adaptations[klass].empty?
      methods = klass.instance_methods(false)
      raise Exception, "No methods in class" if methods.empty?
      methods.each do |name|
        # Ignore leftover proceed methods
        next if name.to_s.include? "proceed"
        meth = klass.instance_method(name)
        method_bound = meth.bind(klass.class == Module ? klass : klass.new)
        self.push_adapt(klass, name, nil, method_bound.to_proc)
      end
    end
  end

  # Add an adaptation to the stack
  def push_adapt(klass, method, ctx, impl)
    ci = CI.new(ctx, impl)
    @@adaptations[klass][method].push(ci)
  end

  # Remove an adaptation from the stack
  def pop_adapt(klass, method, ctx)
    self_adapts = @@adaptations[klass][method].select do |ci|
      ci.ctx == ctx
    end
    @@adaptations[klass][method].delete(self_adapts.last)
  end

  # Reset global changes made by the framework
  def self.reset_cop_state
    # Reset methods to the base implementation
    if defined? @@adaptations
      @@adaptations.each do |klass, methods|
        klass.instance_methods(false).each do |name|
          klass.send(:remove_method, name) if name.to_s.include? "proceed"
        end
        methods.each do |m,impls|
          Context.new.send_method(klass, m, impls.first.impl)
        end
      end
    end

    # Reset variables
    Context.set_vars
  end
end
