# Some discussion on this:
# https://groups.google.com/forum/#!msg/julia-users/YP31LM3Qto0/ET-XjN-vQuAJ
#
# All the model parameters
#
# TODO: improve macro hygiene.

__precompile__()

module Parameters
import Base: @__doc__
import DataStructures: OrderedDict

using Compat

export @with_kw, type2dict, reconstruct, @unpack, @pack

## Parser helpers
#################

# To iterate over code blocks dropping the line-number bits:
immutable Lines
    block::Expr
end
Base.start(lns::Lines) = 1
function Base.next(lns::Lines, nr)
    for i=nr:length(lns.block.args)
        if isa(lns.block.args[i], LineNumberNode)
            continue
        end
        if isa(lns.block.args[i], Symbol) || !(lns.block.args[i].head==:line)
            return lns.block.args[i], i+1
        end
    end
    return -1
end
function Base.done(lns::Lines, nr)
    if next(lns::Lines, nr)==-1
        true
    else
        false
    end
end
# This is not O(1) but hey...
function Base.setindex!(lns::Lines, val, ind)
    ii = 1
    for i=1:length(lns.block.args)
        if isa(lns.block.args[i], LineNumberNode)
            continue
        end
        if isa(lns.block.args[i], Symbol) || !(lns.block.args[i].head==:line)
            if ind==ii
                lns.block.args[i] = val
                return nothing
            end
            ii +=1
        end
    end
    throw(BoundsError("Attempted to set line $ind of $(ii-1) length code-block"))
end

# Transforms :(a::b) -> :a
decolon2(a::Expr) = (@assert a.head==:(::);  a.args[1])
decolon2(a::Symbol) = a

# Keeps the ::T of the args if T ∈ typparas
function keep_only_typparas(args, typparas)
    args = deepcopy(args)
    typparas_ = map(stripsubtypes, typparas)
    for i=1:length(args)
        isa(args[i],Symbol) && continue
        @assert args[i].head==:(::)
        T = args[i].args[2]
        if !(symbol_in(typparas_, T))
            args[i] = decolon2(args[i])
        end
    end
    args
end

# check whether a symbol is contained in an expression
symbol_in(s::Symbol, ex::Symbol) = s==ex
symbol_in(s::Symbol, ex) = false
function symbol_in(s::Symbol, ex::Expr)
    for a in ex.args
        symbol_in(s,a) && return true
    end
    return false
end
symbol_in(s::Symbol, ex::Vector) = any(map(e->symbol_in(s, e), ex))
symbol_in(s::Vector, ex) = any(map(ss->symbol_in(ss, ex), s))

# Returns the name of the type as Symbol
function typename(typedef::Expr)
    if isa(typedef.args[2], Symbol)
        return typedef.args[2]
    elseif isa(typedef.args[2].args[1], Symbol)
        return typedef.args[2].args[1]
    elseif isa(typedef.args[2].args[1].args[1], Symbol)
        return typedef.args[2].args[1].args[1]
    else
        error("Could not parse type-head from: $typedef")
    end
end

# Transforms:  Expr(:<:, :A, :B) -> :A
stripsubtypes(s::Symbol) = s
function stripsubtypes(e::Expr)
    e.args[1]
end
stripsubtypes(vec::Vector) = [stripsubtypes(v) for v in vec]

function check_inner_constructor(l)
    if l.args[1].head==:where
        fnhead = l.args[1].args[1]
    else
        fnhead = l.args[1]
    end
    if length(fnhead.args)==1
        error("No inner constructors with zero positional arguments allowed!")
    elseif (length(fnhead.args)==2 #1<length(fnhead.args)<=3
            && isa(fnhead.args[2], Expr)
            && fnhead.args[2].head==:parameters)
        error("No inner constructors with zero positional arguments plus keyword arguments allowed!")
    end
    nothing
end

## Exported helper functions
#####################
"""
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
"""
function type2dict(dt)
    di = Dict{Symbol,Any}()
    for n in fieldnames(dt)
        di[n] = getfield(dt, n)
    end
    di
end

"""
Make a new instance of a type with the same values as
the input type except for the fields given in the associative
second argument or as keywords.

```julia
type A; a; b end
a = A(3,4)
b = reconstruct(a, [(:b, 99)]) # ==A(3,99)
```
"""
function reconstruct{T}(pp::T, di)
    di = !isa(di, Associative) ? Dict(di) : di
    ns = fieldnames(pp)
    args = Vector{Any}(length(ns))
    for (i,n) in enumerate(ns)
        args[i] = get(di, n, getfield(pp, n))
    end
    T(args...)
end
reconstruct{T}(pp::T; kws...) = reconstruct(pp, kws)


###########################
# Keyword constructors with @with_kw
##########################

# A type with fields (r,a) in variable aa becomes
# quote
#     r = aa.r
#     a = aa.a
# end
_unpack(binding, fields) = Expr(:block, [:($f = $binding.$f) for f in fields]...)
# Pack fields back into binding using reconstruct:
function _pack(binding, fields)
    kws = [Expr(:kw, f, f) for f in fields]
    :($binding = $Parameters.reconstruct($binding, $(kws...)) )
end

"""
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
    varname = $Parameters.reconstruct(varname,r=r,a=a)
    end)
end
```
"""
function with_kw(typedef)
    if typedef.head!=:type
        error("only works on type-defs")
    end
    const err1str = "Field \'"
    const err2str = "\' has no default, supply it with keyword."

    inner_constructors = Any[]

    # parse a few things
    tn = typename(typedef) # the name of the type
    # Returns M{...} (removes any supertypes)
    if isa(typedef.args[2], Symbol)
        typparas = Any[]
    elseif typedef.args[2].head==:<:
        if isa(typedef.args[2].args[1],Symbol)
            typparas = Any[]
        else
            typparas = typedef.args[2].args[1].args[2:end]
        end
    else
        typparas = typedef.args[2].args[2:end]
    end

    # error on types without fields
    lns = Lines(typedef.args[3])
    if done(lns, start(lns))
        error("@with_kw only supported for types which have at least one field.")
    end
    # default type @deftype
    l, i = next(lns, start(lns))
    if isa(l, Expr) && l.head==:macrocall && l.args[1]==Symbol("@deftype")
        has_deftyp = true
        if length(l.args) != 2
            error("Malformed `@deftype` line")
        end
        deftyp = l.args[2]
        if done(lns, i)
            error("@with_kw only supported for types which have at least one field.")
        end
    else
        has_deftyp = false
    end

    # Expand all macros in body now (only works at top-level)
    # See issue https://github.com/mauro3/Parameters.jl/issues/21
    lns2 = Any[] # need new lines as expanded macros may have many lines
    for (i,l) in enumerate(lns) # loop over body of typedef
        if i==1 && has_deftyp
            push!(lns2, l)
            continue
        end
        if isa(l, Symbol)
            push!(lns2, l)
            continue
        end
        if l.head==:macrocall && l.args[1]!=Symbol("@assert")
            tmp = macroexpand(l)
            if tmp.head==:block
                llns = Lines(tmp)
                for ll in llns
                    push!(lns2, ll)
                end
            else
                push!(lns2,tmp)
            end
        else
            push!(lns2, l)
        end
    end
    lns = lns2

    # the vars for the unpack macro
    unpack_vars = Any[]
    # the type def
    fielddefs = quote end # holds r::R etc
    fielddefs.args = Any[] # in julia 0.5 this is [:( # /home/mauro/.julia/v0.5/Parameters/src/Parameters.jl, line 228:)]
    kws = OrderedDict{Any, Any}()
    # assertions in the body
    asserts = Any[]
    for (i,l) in enumerate(lns) # loop over body of typedef
        if i==1 && has_deftyp
            continue
        end
        if isa(l, Symbol)  # no default value and no type annotation
            if has_deftyp
                push!(fielddefs.args, :($l::$deftyp))
            else
                push!(fielddefs.args, l)
            end
            sym = l
            syms = string(sym)
            kws[sym] = :(error($err1str * $syms * $err2str))
            # unwrap-macro
            push!(unpack_vars, sym)
        elseif l.head==:(=)  # default value and with or without type annotation
            if isa(l.args[1], Expr) && (l.args[1].head==:call || # inner constructor
                                        l.args[1].head==:where && l.args[1].args[1].head==:call) # inner constructor with `where`
                check_inner_constructor(l)
                push!(inner_constructors, l)
            else
                fld = l.args[1]
                if isa(fld, Symbol) && has_deftyp # no type annotation
                    fld = :($fld::$deftyp)
                end
                push!(fielddefs.args, fld)
                kws[decolon2(fld)] = l.args[2]
                # unwrap-macro
                push!(unpack_vars, decolon2(fld))
            end
        elseif l.head==:macrocall  && l.args[1]==Symbol("@assert")
            # store all asserts
            push!(asserts, l)
        elseif l.head==:function # inner constructor
            check_inner_constructor(l)
            push!(inner_constructors, l)
        elseif l.head==:block
            error("No nested begin-end allowed in type defintion")
        else # no default value but with type annotation
            push!(fielddefs.args, l)
            sym = decolon2(l.args[1])
            syms = string(sym)
            kws[sym] = :(error($err1str *$syms * $err2str))
            # unwrap-macro
            push!(unpack_vars, l.args[1])
        end
    end
    # The type definition without inner constructors:
    typ = Expr(:type, deepcopy(typedef.args[1:2])..., deepcopy(fielddefs))

    # Inner keyword constructor.  Note that this calls the positional
    # constructor under the hood and not `new`.  That way a user can
    # provide a special positional constructor (say enforcing
    # invariants) which also gets used with the keywords.
    args = Any[]
    kwargs = Expr(:parameters)
    for (k,w) in kws
        push!(args, k)
        push!(kwargs.args, Expr(:kw,k,w))
    end
    if length(typparas)>0
        tps = stripsubtypes(typparas)
        innerc = :($Compat.@compat (::Type{$tn{$(tps...)}}){$(tps...)}($kwargs) = $tn{$(tps...)}($(args...)) )
        # 0.6 only:
        # innerc = :($tn{$(tps...)}($kwargs) where {$(tps...)} = $tn{$(tps...)}($(args...)))
    else
        innerc = :($tn($kwargs) = $tn($(args...)) )
    end
    push!(typ.args[3].args, innerc)

    # Inner positional constructor: only make it if no inner
    # constructors are user-defined.  If one or several are defined,
    # assume that one has the standard positional signature.
    if length(inner_constructors)==0
        if length(typparas)>0
            tps = stripsubtypes(typparas)
            innerc2 = :($Compat.@compat (::Type{$tn{$(tps...)}}){$(tps...)}($(args...)) = new{$(tps...)}($(args...)))
            # 0.6 only:
            # innerc2 = :($tn{$(tps...)}($(args...)) where {$(tps...)} = new($(args...)))
        else
            innerc2 = :($tn($(args...)) = new($(args...)))
        end
        prepend!(innerc2.args[2].args, asserts)
        push!(typ.args[3].args, innerc2)
    else
        if length(asserts)>0
            error("Assertions are only allowed in type-definitions with no inner constructors.")
        end
        append!(typ.args[3].args, inner_constructors)
    end

    # Outer positional constructor which does not need explicit
    # type-parameters when called.  Only make this constructor if
    #  (1) type parameters are used at all
    #  (2) all type parameters are used in the fields (otherwise get a
    #      "method is not callable" warning!)
    #       See also https://github.com/JuliaLang/julia/issues/17186
    if typparas!=Any[] # condition (1)
        # fields definitions stripped of ::Int etc., only keep ::T if T∈typparas :
        fielddef_strip_contT = keep_only_typparas(fielddefs.args, typparas)
        outer_positional = :(  $tn{$(typparas...)}($(fielddef_strip_contT...))
                             = $tn{$(stripsubtypes(typparas)...)}($(args...)))
        # Check condition (2)
        checks = true
        for tp in stripsubtypes(typparas)
            checks = checks && symbol_in(tp, fielddefs.args)
        end
        if !checks
            outer_positional = :()
        end
    else
        outer_positional = :()
    end

    # Outer keyword constructor, useful to infer the type parameter
    # automatically.  This calls the outer positional constructor.
    # only create if type parameters are used.
    if typparas==Any[]
        outer_kw=:()
    else
        outer_kw = :($tn($kwargs) = $tn($(args...)) )
    end

    ## outer copy constructor
    ###
    outer_copy = quote
        $tn(pp::$tn; kws... ) = reconstruct(pp, kws)
        # $tn(pp::$tn, di::Union(Associative,Vararg{Tuple{Symbol,Any}}) ) = reconstruct(pp, di) # see issue https://github.com/JuliaLang/julia/issues/11537
        # $tn(pp::$tn, di::Union(Associative, Tuple{Vararg{Tuple{Symbol, Any}}}) ) = reconstruct(pp, di) # see issue https://github.com/JuliaLang/julia/issues/11537
        $tn(pp::$tn, di::Associative ) = reconstruct(pp, di)
        $tn(pp::$tn, di::Vararg{Tuple{Symbol,Any}} ) = reconstruct(pp, di)
    end

    # (un)pack macro from https://groups.google.com/d/msg/julia-users/IQS2mT1ITwU/hDtlV7K1elsJ
    unpack_name = Symbol("unpack_"*string(tn))
    pack_name = Symbol("pack_"*string(tn))
    # Finish up
    quote
        Base.@__doc__ $typ
        $outer_positional
        $outer_kw
        $outer_copy
        function Base.show(io::IO, p::$tn)
            # just dumping seems to give ok output, in particular for big data-sets:
            dump(IOContext(io, :limit => true), p, maxdepth=1)
        end
        macro $unpack_name(ex)
            esc($Parameters._unpack(ex, $unpack_vars))
        end
        macro $pack_name(ex)
            esc($Parameters._pack(ex, $unpack_vars))
        end
        $tn
    end
end

"""
Macro which allows default values for field types and a few other features.

Basic usage:

```julia
@with_kw immutable MM{R}
    r::R = 1000.
    a::Int = 4
end
```

For more details see manual.
"""
macro with_kw(typedef)
    return esc(with_kw(typedef))
end

###########################
# Packing and unpacking @unpack, @pack
##########################
# Below code slightly adapted from Simon Danisch's GLVisualize via PR
# https://github.com/mauro3/Parameters.jl/pull/13

"""
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
"""
function unpack end
@inline unpack{f}(x, ::Val{f}) = getfield(x, f)
@inline unpack{k}(x::Associative{Symbol}, ::Val{k}) = x[k]
@inline unpack{S<:AbstractString,k}(x::Associative{S}, ::Val{k}) = x[string(k)]

"""
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
"""
function pack! end
@inline pack!{f}(x, ::Val{f}, val) = setfield!(x, f, val)
@inline pack!{k}(x::Associative{Symbol}, ::Val{k}, val) = x[k]=val
@inline pack!{S<:AbstractString,k}(x::Associative{S}, ::Val{k}, val) = x[string(k)]=val

"""
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
"""
macro unpack(args)
    args.head!=:(=) && error("Expression needs to be of form `a, b = c`")
    items, suitecase = args.args
    items = isa(items, Symbol) ? [items] : items.args
    suitecase_instance = gensym()
    kd = [:( $key = Parameters.unpack($suitecase_instance, Val{$(Expr(:quote, key))}()) )for key in items]
    kdblock = Expr(:block, kd...)
    expr = quote
        $suitecase_instance = $suitecase # handles if suitecase is not a variable but an expression
        $kdblock
        $suitecase_instance # return RHS of `=` as standard in Julia
    end
    esc(expr)
end


"""
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
"""
macro pack(args)
    args.head!=:(=) && error("Expression needs to be of form `a = b,c`")
    suitecase, items = args.args
    items = isa(items, Symbol) ? [items] : items.args
    suitecase_instance = gensym()
    kd = [:( Parameters.pack!($suitecase_instance, Val{$(Expr(:quote, key))}(), $key) ) for key in items]
    kdblock = Expr(:block, kd...)
    expr = quote
        $suitecase_instance = $suitecase # handles if suitecase is not a variable but an expression
        $kdblock
        ($(items...),)
    end
    esc(expr)
end

# TODO: maybe add @pack_new for packing into a new instance.  Could be
# used with immutables also.

end # module
