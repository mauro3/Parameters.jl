# Parameters

[![Documentation Status](https://readthedocs.org/projects/parametersjl/badge/?version=latest)](http://parametersjl.readthedocs.org/en/latest/?badge=latest)

[![Build Status](https://travis-ci.org/mauro3/Parameters.jl.svg?branch=master)](https://travis-ci.org/mauro3/Parameters.jl)
[![Build Status](https://ci.appveyor.com/api/projects/status/github/mauro3/Parameters.jl?branch=master&svg=true)](https://ci.appveyor.com/project/mauro3/parameters-jl/branch/master)

[![Parameters](http://pkg.julialang.org/badges/Parameters_0.4.svg)](http://pkg.julialang.org/?pkg=Parameters&ver=0.4)
[![Parameters](http://pkg.julialang.org/badges/Parameters_0.5.svg)](http://pkg.julialang.org/?pkg=Parameters&ver=0.5)

***Breaking news: `@unpack` and `@pack` have new syntax but also lead
   to type-unstable code in Julia 0.4.***

This is a package I use to handle numerical-model parameters, thus the
name.  However, it should be useful otherwise too.  It has two main
features:

- keyword type constructors with default values, and
- unpacking and packing of composite types and dicts.

The macro `@with_kw` which decorates a type definition to
allow default values and a keyword constructor:
```julia
julia> using Parameters

julia> @with_kw type A
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

Unpacking is done with `@unpack` (`@pack` is similar):
```julia
type A
    a
    b
    c
end
@unpack a, c = A(4,5,6)
# is equivalent to
AA = A(4,5,6)
a = AA.a
c = AA.c
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
- generic packing and unpacking macros `@pack`, `@unpack` (work with
  any types).

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

Documentation is [here](http://parametersjl.readthedocs.org/en/latest/?badge=latest).

# Related packages

- [QuickTypes.jl](https://github.com/cstjean/QuickTypes.jl) also
  provides key-word constructors and default values.  Provides a more
  compact format.  I'd say QuickTypes.jl is more suited for REPL and
  other write-only code, whereas Parameters.jl may be more suited for
  code which is also read.
- [SimpleStructs.jl](https://github.com/pluskid/SimpleStructs.jl) also
  provides key-word constructors, default values and assertions.  But
  the syntax is less nice than Parameters.jl.

# TODO

- do copy of fields on (re-)construct?
- think about mutables
