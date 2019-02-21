# [Parameters.jl](https://github.com/mauro3/Parameters.jl)

This is a package I use to handle numerical-model parameters, thus the
name.  However, it should be useful otherwise too.  It has two main
features:

- keyword type constructors with default values, and
- unpacking and packing of composite types and dicts.

The keyword-constructor and default-values functionality will probably
make it into Julia
([# 10146](https://github.com/JuliaLang/julia/issues/10146),
[#533](https://github.com/JuliaLang/julia/issues/5333) and
[#6122](https://github.com/JuliaLang/julia/pull/6122)) although
probably not with all the features present in this package.  However,
there is `Base.@kwdef` which covers many of the use cases of
Parameters.jl's keyword constructor.  I suspect that this package
should stay usable & useful even after this change lands in Julia.
Note that keyword functions are currently slow in Julia, so these
constructors should not be used in hot inner loops.  However, the
normal positional constructor is also provided and could be used in
performance critical code.

[NEWS.md](https://github.com/mauro3/Parameters.jl/blob/master/NEWS.md)
keeps tabs on updates.
