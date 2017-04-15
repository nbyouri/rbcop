# LSINF2335 - Programming Paradigms
---

# Project 2 report
Youri Mouton

## Question 1
> How do you save/restore the default implementation of a method.

The adaptations are structured in a hashmap of `klass,methods` where `methods` is a hashmap of `method,impls` and where `impls` is an array of the class `CI`. The class `CI` contains two variables, a Context' self value and the block itself.

On the first `adapt` call of a context, the existing methods of `klass` are added as first elements of the adaptations hashmap using `instance_methods` and binding the methods to the klass and thus get the default implementation. 

The default implementation is restored by getting the first element of the adaptations array and defining the method to overwrite previous implementations resulting of activations.

## Question 2
>How do you ensure that the receiver is bound when an adaptation is
installed?

Using `define_method` defines an instance method in the receiver. We have to use `send` to execute `define_method` on the klass because it is private.

The `CI` structure contains the receiver's self and the implementation to keep track.

## Question 3
> Can your framework adapt any method? Think about where methods can be
defined and what parameters they can have. If no, why not? If yes, how did
you do it?

My tests include defining adaptations with the following types of methods parameters, but all parameters types seem to be working:

| type | test |
|------|------|
| required | { \|x,y\| x + y } |
| optional | { \|x = 2\| x } |
| array decomposition | { \|x,*y\| y } |
| block | { \|&block\| lambda { block } } |

The framework can also adapt module methods easily as the following test shows:

```ruby
module M
  def foo; 5; end
end

class T
  include M
end

class ModuleTests < Test::Unit::TestCase
  def test_module
    reset_cop_state
    c = Context.new
    c.activate
    c.adapt(M, :foo) { 1  }
    assert_equal(1, T.new.foo)
  end
end
```

## Question 4
> Describe the semantics of your extra feature. If any interesting tricks were
used to implement it, mention them.

The extra feature I implemented is the following:

> Make it so that multiple context activations require an equal number of
context deactivation. Moreover, a context's adaptations priority should return to their previous priority.

The `CI` class was extended to add priority for an adaptation and the activate 
