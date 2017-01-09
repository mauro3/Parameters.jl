# 2017-01-09

Dropping Julia 0.4 support

# 2016-09-16 v0.5.0

Updated packing and unpacking macro syntax according to PR
[#13](https://github.com/mauro3/Parameters.jl/pull/13).  Before
`@pack` was supported for immutable (via invoking `reconstruct`), this
has been dropped.

Also, `@unpack` performance on Julia-0.4 will be sub-par with this
change as it is type unstable.

This is a breaking change!

# 2016-09-14 v0.4.0

Now keyword constructor calls can be done without
type-parameters. Fixes issue [#10](https://github.com/mauro3/Parameters.jl/issues/10).

# 2016-01-15

Added support for `@assert` in type-body.

# 2015-11-24

Added `@deftype` to specify a default type annotation.

# 2015-11-23

Dropped Docile support (on 0.3)

Allowing documenting types created with `@with_kw`

# 2015-08-17

Added `@pack` and `@unpack` macros:

```julia
type A
    a
    b
end
aa = A(3,4)
@unpack aa, b # does: b = aa.b
```
