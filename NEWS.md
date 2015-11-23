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
