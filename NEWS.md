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
