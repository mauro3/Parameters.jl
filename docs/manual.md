# Parameters manual

This is a manual by example
([examples/ex1.jl](https://github.com/mauro3/Parameters.jl/blob/master/examples/ex1.jl)).

# Types with default values

Create a type which has default values:
```julia
using Parameters

@with_kw immutable PhysicalPara{R}
    rw::R = 1000.
    ri::R = 900.
    L::R = 3.34e5
    g::R = 9.81
    cw::R = 4220.
    day::R = 24*3600.
end
```
&nbsp;

Now the type can be constructed using the default values, or with
non-defaults specified with keywords:
```julia
# Create an instance with the defaults
pp = PhysicalPara{Float64}()
# Make one with some non-defaults
pp2 = PhysicalPara{Float32}(cw=77, day= 987)
# Make another one based on the previous one with some modifications
pp3 = PhysicalPara(pp2; cw=.11e-7, rw=100.)
```
&nbsp;

To enforce constraints on the values, it's possible to use `@assert`s
straight inside the type-def.  (As usual, for mutables these
asserts can be violated by updating the fields after type construction.)
```julia
@with_kw immutable PhysicalPara2{R}
    rw::R = 1000.; @assert rw>0
    ri::R = 900.
    @assert rw>ri # Note that the placement of assertions is not
                  # relevant. (They are moved to the constructor.
end
```
&nbsp;

Parameter interdependence is possible (note that they needn't appear in order):
```julia
@with_kw immutable Para{R<:Real}
    a::R = 5
    b::R
    c::R = a+b
end
pa = Para{Int}(b=7)
```
&nbsp;

Often the bulk of fields will have the same type.  To help with this,
a default type can be set.  Using this feature, the last example (with
additional field `d`) can be written more compactly as:
```julia
@with_kw immutable Para2{R<:Real} @deftype R
    a = 5
    b
    c = a+b
    d::Int = 4 # adding a type overrides the @deftype
end
pa2 = Para2{Int}(b=7)

# or more pedestrian
@with_kw immutable Para3 @deftype Float64
    a = 5
    b
    c = a+b
    d::Int = 4
end
pa3 = Para3(b=7)
```
&nbsp;

Custom inner constructors can be defined as long as:

- one defining all positional arguments is given
- no zero-positional arguments constructor is defined (as that
  would clash with the keyword constructor)
- no `@assert`s (as in above example) are used within the type body.

The keyword constructor goes through the positional constructor, thus
invariants or any other calculation will be honored.
```julia
@with_kw immutable MyS{R}
    a::R = 5
    b = 4
    MyS(a,b) = (@assert a>b; new(a,b)) #
    MyS(a) = MyS{R}(a, a-1) # For this provide your own outer constructor:
end
MyS{R}(a::R) = MyS{R}(a)

MyS{Int}() # MyS(5,4)
ms = MyS(3) # MyS(3,2)
MyS(ms, b=-1) # MyS(3,-1)
try
    MyS(ms, b=6) # this will fail the assertion
end
```
Note that two of the main reasons to have an inner constructor,
assertions and simple calculations, are more easily achieved with
`@assert`s and parameter interdependence.

# (Un)pack macros

When working with parameters it is often convenient to unpack (and
pack) some or all of them, in particular inside functions.

The preferred and safer way to do this is using the `@unpack` and
`@pack` macros (which are generic and also work with non-`@with_kw` types):
```julia
function fn2(var, pa::Para)
    @unpack pa: a, b # equivalent to: a,b = pa.a,pa.b
    out = var + a + b
    b = 77
    @pack pa: b # equivalent to: pa.b=b
    return out, pa
end

out, pa = fn1(7, pa)
```
&nbsp;

The `@with_kw` macro automatically produces type-specific (un-)pack
macros which unpack all fields:
```julia
function fn(var, pa::Para)
    @unpack_Para pa # the macro is constructed during the @with_kw
                    # and called @unpack_*
    out = var + a + b
    b = 77
    @pack_Para pa
    return out, pa
end

out, pa = fn(7, pa)
```

However, note that the (un-)packing macros which unpack all fields
have a few pitfalls, as changing the type definition will change what
local variables are available in a function using `@unpack_*`.  Examples:

- adding a field `pi` to a type would hijack `Base.pi` usage in any
  function using `@unpack_*`
- the `@unpack_*` will shadow an input argument of the function with
  the same name as a type-fieldname.  This I found very perplexing at
  times.

Thus, in general, it is probably better to use the `@(un)pack` macros instead.
