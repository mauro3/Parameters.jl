# [Parameters.jl](https://github.com/mauro3/Parameters.jl)

This Julia package provides types which have default values and
keyword constructors. I use it to handle numerical-model parameters,
thus the name.  However, it should be useful otherwise too.  Its main
feature is the macro `@with_kw` which decorates a type definition and
creates:

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
