# Parameters manual

This is a manual by example
([examples/ex1.jl](https://github.com/mauro3/Parameters.jl/blob/master/examples/ex1.jl)).

# Types with default values & keyword constructors

Create a type which has default values using [`@with_kw`](@ref):

```julia
using Parameters

@with_kw struct PhysicalPara{R}
    rw::R = 1000.
    ri::R = 900.
    L::R = 3.34e5
    g::R = 9.81
    cw::R = 4220.
    day::R = 24*3600.
end
```

Now the type can be constructed using the default values, or with
non-defaults specified with keywords:

```julia
# Create an instance with the defaults
pp = PhysicalPara()
pp_f32 = PhysicalPara{Float32}() # the type parameter can be chosen explicitly
# Make one with some non-defaults
pp2 = PhysicalPara(cw=77.0, day= 987.0)
# Make another one based on the previous one with some modifications
pp3 = PhysicalPara(pp2; cw=.11e-7, rw=100.)
# the normal positional constructor can also be used
# (and should be used in hot inner loops)
pp4 = PhysicalPara(1,2,3,4,5,6)
```

To enforce constraints on the values, it's possible to use `@assert`s
straight inside the type-def. (As usual, for mutables these
asserts can be violated by updating the fields after type construction.)

```julia
@with_kw struct PhysicalPara2{R}
    rw::R = 1000.; @assert rw>0
    ri::R = 900.
    @assert rw>ri # Note that the placement of assertions is not
                  # relevant. (They are moved to the constructor.
end
```

Parameter interdependence is possible:

```julia
@with_kw struct Para{R<:Real}
    a::R = 5
    b::R
    c::R = a+b
end
pa = Para(b=7)
```

Often the bulk of fields will have the same type. To help with this,
a default type can be set. Using this feature, the last example (with
additional field `d`) can be written more compactly as:

```julia
@with_kw struct Para2{R<:Real} @deftype R
    a = 5
    b
    c = a+b
    d::Int = 4 # adding a type overrides the @deftype
end
pa2 = Para2(b=7)

# or more pedestrian
@with_kw struct Para3 @deftype Float64
    a = 5
    b
    c = a+b
    d::Int = 4
end
pa3 = Para3(b=7)
```

Custom inner constructors can be defined as long as:

- one defining all positional arguments is given
- no zero-positional arguments constructor is defined (as that
  would clash with the keyword constructor)
- no `@assert`s (as in above example) are used within the type body.

The keyword constructor goes through the inner positional constructor,
thus invariants or any other calculation will be honored.

```julia
@with_kw struct MyS{R}
    a::R = 5
    b = 4
    MyS{R}(a,b) where {R} = (@assert a>b; new(a,b)) #
    MyS{R}(a) where {R} = MyS{R}(a, a-1) # For this provide your own outer constructor:
end
MyS(a::R) where {R} = MyS{R}(a)

MyS{Int}() # MyS(5,4)
ms = MyS(3) # MyS(3,2)
MyS(ms, b=-1) # MyS(3,-1)
try
    MyS(ms, b=6) # this will fail the assertion
catch
end
```

Note that two of the main reasons to have an inner constructor,
assertions and simple calculations, are more easily achieved with
`@assert`s and parameter interdependence.

The macro `@with_kw` defines a show-method which is, hopefully, more informative than the
standard one. For example the printing of the first example is:

```julia
julia> PhysicalPara()
PhysicalPara{Float64}
  rw: Float64 1000.0
  ri: Float64 900.0
  L: Float64 334000.0
  g: Float64 9.81
  cw: Float64 4220.0
  day: Float64 86400.0
```

If this `show` method definition is not desired, for instance because of method
re-definition warnings, then use [`@with_kw_noshow`](@ref).

## Named Tuple Support

As mentioned in the README, the `@with_kw` macro can be used to decorate a named tuple and produce a named tuple constructor with those defaults.

These named tuples can be defined as such:

```julia
MyNT = @with_kw (f = x -> x^3, y = 3, z = "foo")
```

And the constructors can be used as follows:

```julia
julia> MyNT(f = x -> x^2, z = :foo)
(f = #12, y = 3, z = :foo)
```

The constructor is not type-locked:

```julia
julia> MyNT(f = "x -> x^3")
(f = "x -> x^3", y = 3, z = "foo")
```

And these named tuples can unpacked in the usual way (see below).

```julia
julia> @unpack f, y, z = MyNT()
(f = #7, y = 3, z = "foo")

julia> f
(::#7) (generic function with 1 method)

julia> y
3

julia> z
"foo"
```

Since the macro operates on a single tuple expression (as opposed to a tuple of assignment expressions),writing `@with_kw(x = 1, y = :foo)` will return an error suggesting you write `@with_kw (x = 1, y = :foo)`.

# Blocks of constants

Several constants can be defined like so:
```julia
@consts begin
    a = 1
    b = 2
    c = 3
end
```
(if you do the math, you'll need more than three constants in the block to actually save typing.)


# (Un)pack macros

## `@unpack` and `@pack` re-exported from UnPack.jl

When working with parameters, or otherwise, it is often convenient to
unpack (and pack, in the case of mutable datatypes) some or all of the
fields of a type.  This is often the case when passed into a function.

The preferred to do this is using the `@unpack` and
`@pack!` macros from the package
[UnPack.jl](https://github.com/mauro3/UnPack.jl).  These are generic
and also work with non-`@with_kw` stucts, named-tuples, modules, and
dictionaries.
Here one example is given, for more see the README of
UnPack. Define a mutable struct `MPara`:

```julia
@with_kw mutable struct MPara{R<:Real}
    a::R = 5
    b::R
    c::R = a+b
end
pa = MPara(b=7)

function fn2(var, pa::MPara)
    @unpack a, b = pa # equivalent to: a,b = pa.a,pa.b
    out = var + a + b
    b = 77
    @pack! pa = b # equivalent to: pa.b = b
    return out, pa
end

out, pa = fn2(7, pa)
```

Note that `@unpack` and `@pack!` can be customized on types,
see [UnPack.jl](https://github.com/mauro3/UnPack.jl).

## The type-specific (un)pack-all macros (somewhat dangerous)

The `@with_kw` macro automatically produces type-specific (un-)pack
macros of form `@unpack_TypeName`, `@pack_TypeName!`, and
`@pack_TypeName` which unpack/pack all fields:

```julia
function fn(var, pa::Para)
    @unpack_Para pa # the macro is constructed during the @with_kw
                    # and called @unpack_*
    out = var + a + b
    b = 77
    @pack_Para! pa # only works with mutables
    return out, pa
end

out, pa = fn(7, pa)
```

When needing a new instance, e.g. for immutables, use the no-bang version:
```
pa2 = @pack_Para
```

However, note that the (un-)packing macros which unpack all fields
have a few pitfalls, as changing the type definition will change what
local variables are available in a function using `@unpack_*`. Examples:

- adding a field `pi` to a type would hijack `Base.pi` usage in any
  function using `@unpack_*`
- the `@unpack_*` will shadow an input argument of the function with
  the same name as a type-fieldname. This I found very perplexing at
  times.
- they do not work with properties, i.e. they can only pack/unpack the
  actual fields of types.

Thus, in general, it is probably better to use the `@(un)pack(!)` macros instead.
