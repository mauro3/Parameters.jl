# Parameters

## Exported

---

<a id="method__reconstruct.1" class="lexicon_definition"></a>
#### reconstruct{T}(pp::T) [¶](#method__reconstruct.1)
Make a new instance of a type with the same values as
the input type except for the fields given in the associative
second argument or as keywords.

```julia
type A; a; b end
a = A(3,4)
b = reconstruct(a, [(:b, 99)]) # ==A(3,99)
```


*source:*
[Parameters/src/Parameters.jl:119](https://github.com/mauro3/Parameters.jl/tree/a0724f3a5779d25a60a18abda02d736cdc260bb3/src/Parameters.jl#L119)

---

<a id="method__type2dict.1" class="lexicon_definition"></a>
#### type2dict(dt) [¶](#method__type2dict.1)
Transforms a type-instance into a dictionary.

```
julia> type T
           a
           b
       end

julia> type2dict(T(4,5))
Dict{Symbol,Any} with 2 entries:
  :a => 4
  :b => 5
```


*source:*
[Parameters/src/Parameters.jl:103](https://github.com/mauro3/Parameters.jl/tree/a0724f3a5779d25a60a18abda02d736cdc260bb3/src/Parameters.jl#L103)

---

<a id="macro___pack.1" class="lexicon_definition"></a>
#### @pack(arg) [¶](#macro___pack.1)
Packs values into a datatype.  The variables need to have the same
name as the fields.  If the datatype is mutable, it will be mutated.
If immutable, a new instance is made with `reconstruct` and assigned
to the original variable.

```julia
type A
    a
    b
end
aa = A(3,4)
b = "ha"
@pack aa: b
# is equivalent to
aa.b = b
```


*source:*
[Parameters/src/Parameters.jl:465](https://github.com/mauro3/Parameters.jl/tree/a0724f3a5779d25a60a18abda02d736cdc260bb3/src/Parameters.jl#L465)

---

<a id="macro___unpack.1" class="lexicon_definition"></a>
#### @unpack(arg) [¶](#macro___unpack.1)
Unpacks fields from any datatype (no need to create it with @with_kw):

```julia
type A
    a
    b
end
aa = A(3,4)
@unpack aa: a,b
# is equivalent to
a = aa.a
b = aa.b
```


*source:*
[Parameters/src/Parameters.jl:435](https://github.com/mauro3/Parameters.jl/tree/a0724f3a5779d25a60a18abda02d736cdc260bb3/src/Parameters.jl#L435)

---

<a id="macro___with_kw.1" class="lexicon_definition"></a>
#### @with_kw(typedef) [¶](#macro___with_kw.1)
Macro which allows default values for field types and a few other features.

Basic usage:

```julia
@with_kw immutable MM{R}
    r::R = 1000.
    a::Int = 4
end
```

For more details see manual.


*source:*
[Parameters/src/Parameters.jl:395](https://github.com/mauro3/Parameters.jl/tree/a0724f3a5779d25a60a18abda02d736cdc260bb3/src/Parameters.jl#L395)

## Internal

---

<a id="method__with_kw.1" class="lexicon_definition"></a>
#### with_kw(typedef) [¶](#method__with_kw.1)
This function is called by the `@with_kw` macro and does the AST transformation from:

```julia
@with_kw immutable MM{R}
    r::R = 1000.
    a::R
end
```

into

```julia
immutable MM{R}
    r::R
    a::R
    MM(r,a) = new(r,a)
    MM(;r=1000., a=error("no default for a")) = MM{R}(r,a)
end
MM(m::MM; kws...) = reconstruct(mm,kws)
MM(m::MM, di::Union{Associative, Tuple{Symbol,Any}}) = reconstruct(mm, di)
macro unpack_MM(varname)
    esc(quote
    r = varname.r
    a = varname.a
    end)
end
macro pack_MM(varname)
    esc(quote
    varname = Main.Parameters.reconstruct(varname,r=r,a=a)
    end)
end
```


*source:*
[Parameters/src/Parameters.jl:198](https://github.com/mauro3/Parameters.jl/tree/a0724f3a5779d25a60a18abda02d736cdc260bb3/src/Parameters.jl#L198)

