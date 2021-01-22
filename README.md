# Parameters

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://mauro3.github.io/Parameters.jl/stable)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://mauro3.github.io/Parameters.jl/dev)

[![Build Status](https://github.com/mauro3/Parameters.jl/workflows/CI/badge.svg)](https://github.com/mauro3/Parameters.jl/actions)
[![Build Status](https://ci.appveyor.com/api/projects/status/github/mauro3/Parameters.jl?branch=master&svg=true)](https://ci.appveyor.com/project/mauro3/parameters-jl/branch/master)
[![Coverage](https://codecov.io/gh/mauro3/Parameters.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/mauro3/Parameters.jl)
[![pkgeval](https://juliahub.com/docs/Parameters/pkgeval.svg)](https://juliahub.com/ui/Packages/Parameters/ycYNs)


[![deps](https://juliahub.com/docs/Parameters/deps.svg)](https://juliahub.com/ui/Packages/Parameters/ycYNs?t=2)
[![version](https://juliahub.com/docs/Parameters/version.svg)](https://juliahub.com/ui/Packages/Parameters/ycYNs)

This is a package I use to handle numerical-model parameters, thus the
name.  However, it should be useful otherwise too.  It has two main
features:

- keyword type constructors with default values for `struct`s and `NamedTuples`,
- unpacking and packing of composite types and dicts (mostly via [UnPack.jl](https://github.com/mauro3/UnPack.jl)).

Checkout my ten minute JuliaCon 2018 [talk](https://youtu.be/JFrzrTYFYbU?t=1m).

The macro `@with_kw` which decorates a type definition to
allow default values and a keyword constructor:
```julia
julia> using Parameters

julia> @with_kw struct A
           a::Int = 6
           b::Float64 = -1.1
           c::UInt8
       end

julia> A(c=4)
A
  a: 6
  b: -1.1
  c: 4

julia> A()
ERROR: Field 'c' has no default, supply it with keyword.

julia> A(c=4, a = 2)
A
  a: 2
  b: -1.1
  c: 4
```

The macro also supports constructors for named tuples with default values; e.g.

```julia
julia> MyNT = @with_kw (x = 1, y = "foo", z = :(bar))
(::#5) (generic function with 2 methods)

julia> MyNT()
(x = 1, y = "foo", z = :bar)

julia> MyNT(x = 2)
(x = 2, y = "foo", z = :bar)
```

Unpacking is done with `@unpack` (`@pack!` is similar):
```julia
struct B
    a
    b
    c
end
@unpack a, c = B(4,5,6)
# is equivalent to
BB = B(4,5,6)
a = BB.a
c = BB.c
```

Defining several constants
```julia
@consts begin
    a = 1
    b = 2.0
    c = "a"
end
```


The features are:

- a keyword constructor for the type
- allows setting default values for the fields inside the type
  definition
- allows assertions on field values inside the type definition
- a constructor which allows creating a type-instance taking its defaults from
  another type instance
- packing and unpacking macros for the type: `@unpack_*` where `*` is
  the type name.
- generic packing and unpacking macros `@pack!`, `@unpack` (work with
  any types, via [UnPack.jl](https://github.com/mauro3/UnPack.jl))
- `@consts` macro to defined a bunch of constants

The keyword-constructor and default-values functionality will probably
make it into Julia
([# 10146](https://github.com/JuliaLang/julia/issues/10146),
[#533](https://github.com/JuliaLang/julia/issues/5333) and
[#6122](https://github.com/JuliaLang/julia/pull/6122)) although
probably not with all the features present in this package.  I suspect
that this package should stay usable & useful even after this change
lands in Julia.  Note that keyword functions are currently slow in
Julia, so these constructors should not be used in hot inner loops.
However, the normal positional constructor is also provided and could be
used in performance critical code.

[NEWS.md](https://github.com/mauro3/Parameters.jl/blob/master/NEWS.md)
keeps tabs on updates.

# Documentation

Documentation is here: [stable](https://mauro3.github.io/Parameters.jl/stable) and [latest](https://mauro3.github.io/Parameters.jl/latest).

# Related packages

Complementary:
- [EponymTuples.jl](https://github.com/tpapp/EponymTuples.jl) packing/unpacking
  of named tuples.
- [NamedTupleTools.jl](https://github.com/JeffreySarnoff/NamedTupleTools.jl)
  has many named-tuple helper functions
- [Setfield.jl](https://github.com/jw3126/Setfield.jl) for setting
  immutable fields (i.e. similar to the here provided packing).

Implementing similar things:
- `Base.@kwdef` has functionality similar to `@with_kw` but more
  limited.  However, with Julia v1.1 its capabilities will be much
  enhanced, see [#29316](https://github.com/JuliaLang/julia/pull/29316).
  If that is enough, ditch the Parameters.jl dependency.
- [QuickTypes.jl](https://github.com/cstjean/QuickTypes.jl) also
  provides key-word constructors and default values.  Provides a more
  compact format.  I'd say QuickTypes.jl is more suited for REPL and
  other write-only code, whereas Parameters.jl may be more suited for
  code which is also read.
- [SimpleStructs.jl](https://github.com/pluskid/SimpleStructs.jl) also
  provides key-word constructors, default values and assertions.  But
  the syntax is less nice than Parameters.jl.
- [ExtractMacro.jl](https://github.com/carlobaldassi/ExtractMacro.jl) also has
  the `@unpack` functionality.
- [FieldDefaults.jl](https://github.com/rafaqz/FieldDefaults.jl) also has
  keyword defaults. You can use it as a minimalist replacement for Parameters.jl
  with the aid of [FieldMetadata.jl](https://github.com/rafaqz/FieldMetadata.jl)
  and [Flatten.jl](https://github.com/rafaqz/Flatten.jl).

# TODO

- do copy of fields on (re-)construct?
- think about mutables
