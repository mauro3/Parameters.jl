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
[Parameters/src/Parameters.jl:122](https://github.com/mauro3/Parameters.jl/tree/87ffb34adb3555fded8cfc2227d4defd22a38be7/src/Parameters.jl#L122)

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
[Parameters/src/Parameters.jl:106](https://github.com/mauro3/Parameters.jl/tree/87ffb34adb3555fded8cfc2227d4defd22a38be7/src/Parameters.jl#L106)

---

<a id="macro___pack.1" class="lexicon_definition"></a>
#### @pack(args) [¶](#macro___pack.1)
Packs variables into a composite type or a `Dict{Symbol}`
```julia_skip
@pack dict_or_typeinstance = a, b, c
```

Example with dict:
```julia
a = 5.0
c = "Hi!"
d = Dict{Symbol,Any}()
@pack d = a, c
d # Dict{Symbol,Any}(:a=>5.0,:c=>"Hi!")
```

Example with type:
```julia
a = 99
c = "HaHa"
type A; a; b; c; end
d = A(4,7.0,"Hi")
@pack d = a, c
d.a == 99 #true
d.c == "HaHa" #true
```


*source:*
[Parameters/src/Parameters.jl:541](https://github.com/mauro3/Parameters.jl/tree/87ffb34adb3555fded8cfc2227d4defd22a38be7/src/Parameters.jl#L541)

---

<a id="macro___unpack.1" class="lexicon_definition"></a>
#### @unpack(args) [¶](#macro___unpack.1)
Unpacks fields/keys from a composite type or a `Dict{Symbol}` into variables
```julia_skip
@unpack a, b, c = dict_or_typeinstance
```

Example with dict:
```julia
d = Dict{Symbol,Any}(:a=>5.0,:b=>2,:c=>"Hi!")
@unpack a, c = d
a == 5.0 #true
c == "Hi!" #true
```

Example with type:
```julia
type A; a; b; c; end
d = A(4,7.0,"Hi")
@unpack a, c = d
a == 4 #true
c == "Hi!" #true
```


*source:*
[Parameters/src/Parameters.jl:497](https://github.com/mauro3/Parameters.jl/tree/87ffb34adb3555fded8cfc2227d4defd22a38be7/src/Parameters.jl#L497)

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
[Parameters/src/Parameters.jl:401](https://github.com/mauro3/Parameters.jl/tree/87ffb34adb3555fded8cfc2227d4defd22a38be7/src/Parameters.jl#L401)

## Internal

---

<a id="function__pack.1" class="lexicon_definition"></a>
#### Parameters.pack! [¶](#function__pack.1)
This function is invoked to pack one entity into some DataType and has
signature:

`pack!(dt::Any, ::Val{field}, value) -> value`

Note that this means the only symbols or immutable field-descriptors
are allowed, as they are used as type parameter in `Val`.

Two definitions are included in the package to pack into a composite
type or into a dictionary with Symbol or string keys:

```
@inline pack!{f}(x, ::Val{f}, val) = setfield!(x, f, val)
@inline pack!{k}(x::Associative{Symbol}, ::Val{k}, val) = x[k]=val
@inline pack!{S<:AbstractString,k}(x::Associative{S}, ::Val{k}, val) = x[string(k)]=val
```

More methods can be added to allow for specialized packing of other
datatypes.

See also `unpack`.


*source:*
[Parameters/src/Parameters.jl:465](https://github.com/mauro3/Parameters.jl/tree/87ffb34adb3555fded8cfc2227d4defd22a38be7/src/Parameters.jl#L465)

---

<a id="function__unpack.1" class="lexicon_definition"></a>
#### Parameters.unpack [¶](#function__unpack.1)
This function is invoked to unpack one field/entry of some DataType
`dt` and has signature:

`unpack(dt::Any, ::Val{field}) -> value of field`

The `field` is the symbol of the assigned variable.

Three definitions are included in the package to unpack a composite type
or a dictionary with Symbol or string keys:
```
@inline unpack{f}(x, ::Val{f}) = getfield(x, f)
@inline unpack{k}(x::Associative{Symbol}, ::Val{k}) = x[k]
@inline unpack{S<:AbstractString,k}(x::Associative{S}, ::Val{k}) = x[string(k)]
```

More methods can be added to allow for specialized unpacking of other datatypes.

See also `pack!`.


*source:*
[Parameters/src/Parameters.jl:435](https://github.com/mauro3/Parameters.jl/tree/87ffb34adb3555fded8cfc2227d4defd22a38be7/src/Parameters.jl#L435)

---

<a id="method__with_kw.1" class="lexicon_definition"></a>
#### with_kw(typedef) [¶](#method__with_kw.1)
This function is called by the `@with_kw` macro and does the syntax
transformation from:

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
    MM(;r=1000., a=error("no default for a")) = MM{R}(r,a) # inner kw, type-paras are required when calling
end
MM{R}(r::R,a::R) = MM{R}(r,a) # default outer positional constructor
MM(;r=1000,a=error("no default for a")) =  MM(r,a) # outer kw, so no type-paras are needed when calling
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
[Parameters/src/Parameters.jl:211](https://github.com/mauro3/Parameters.jl/tree/87ffb34adb3555fded8cfc2227d4defd22a38be7/src/Parameters.jl#L211)

