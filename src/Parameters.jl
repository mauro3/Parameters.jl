__precompile__()

"""
This is a package I use to handle numerical-model parameters,
thus the name. However, it should be useful otherwise too.
It has two main features:
- keyword type constructors with default values, and
- unpacking and packing of composite types and dicts.

The macro `@with_kw` which decorates a type definition to
allow default values and a keyword constructor:

```
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
```

Unpacking is done with `@unpack` (`@pack!` is similar):
```
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
"""
module Parameters
import Base: @__doc__
import OrderedCollections: OrderedDict
using UnPack: @unpack, @pack!

export @with_kw, @with_kw_noshow, type2dict, reconstruct, @unpack, @pack!, @pack, @consts

## Parser helpers
#################

# To iterate over code blocks dropping the line-number bits:
struct Lines
    block::Expr
end
start(lns::Lines) = 1
function next(lns::Lines, nr)
    for i=nr:length(lns.block.args)
        if lns.block.args[i] isa LineNumberNode
            continue
        end
        if ( lns.block.args[i] isa Symbol
             || lns.block.args[i] isa String # doc-string
             || !(lns.block.args[i].head==:line))
            return lns.block.args[i], i+1
        end
    end
    return -1
end
function done(lns::Lines, nr)
    if next(lns::Lines, nr)==-1
        true
    else
        false
    end
end
function Base.iterate(lns::Lines, nr=start(lns))
    nr = next(lns, nr)
    return nr == -1 ? nothing : nr
end

# This is not O(1) but hey...
function Base.setindex!(lns::Lines, val, ind)
    ii = 1
    for i=1:length(lns.block.args)
        if lns.block.args[i] isa LineNumberNode
            continue
        end
        if lns.block.args[i] isa Symbol || !(lns.block.args[i].head==:line)
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

# Keep the ::T of the args if T ∈ typparas,
# leave symbols as is, drop field-doc-strings.
function keep_only_typparas(args, typparas)
    args = copy(args)
    tokeep = Int[]
    typparas_ = map(stripsubtypes, typparas)
    for i=1:length(args)
        isa(args[i], String) && continue # do not keep field doc-strings
        push!(tokeep, i)
        isa(args[i], Symbol) && continue
        # keep the typepara if ∈ typparas
        @assert args[i].head==:(::)
        T = args[i].args[2]
        if !(symbol_in(typparas_, T))
            args[i] = decolon2(args[i])
        end
    end
    args[tokeep]
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
    if typedef.args[2] isa Symbol
        return typedef.args[2]
    elseif typedef.args[2].args[1] isa Symbol
        return typedef.args[2].args[1]
    elseif typedef.args[2].args[1].args[1] isa Symbol
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
            && fnhead.args[2] isa Expr
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
julia> struct T
           a
           b
       end

julia> type2dict(T(4,5))
Dict{Symbol,Any} with 2 entries:
  :a => 4
  :b => 5
```

Note that this uses `getproperty`.
"""
function type2dict(dt)
    di = Dict{Symbol,Any}()
    for n in propertynames(dt)
        di[n] = getproperty(dt, n)
    end
    di
end

"""
    reconstruct(pp; kws...
    reconstruct(T::Type, pp; kws...)

Make a new instance of a type with the same values as the input type
except for the fields given in the keyword args.  Works for types, Dicts,
and NamedTuples.  Can also reconstruct to another type, which is probably
mostly useful for parameterised types where the parameter changes on
reconstruction.

Note: this is not very performant.  Check Setfield.jl for a faster &
nicer implementation.

```jldoctest
julia> using Parameters

julia> struct A
           a
           b
       end

julia> x = A(3,4)
A(3, 4)

julia> reconstruct(x, b=99)
A(3, 99)

julia> struct B{T}
          a::T
          b
       end

julia> y = B(sin, 1)
B{typeof(sin)}(sin, 1)

julia> reconstruct(B, y, a=cos) # note reconstruct(y, a=cos) errors!
B{typeof(cos)}(cos, 1)
```
"""
reconstruct(pp::T, di) where T = reconstruct(T, pp, di)
reconstruct(pp; kws...) = reconstruct(pp, kws)
reconstruct(T::Type, pp; kws...) = reconstruct(T, pp, kws)
function reconstruct(::Type{T}, pp, di) where T
    di = !isa(di, AbstractDict) ? Dict(di) : copy(di)
    ns = if T<:AbstractDict
        if pp isa AbstractDict
            keys(pp)
        else
            fieldnames(typeof(pp))
        end
    else
        fieldnames(T)
    end
    args = []
    for (i,n) in enumerate(ns)
        if pp isa AbstractDict
            push!(args, pop!(di, n, pp[n]))
        else
            push!(args, pop!(di, n, getfield(pp, n)))
        end
    end
    length(di)!=0 && error("Fields $(keys(di)) not in type $T")

    if T<:AbstractDict
        return T(zip(ns,args))
    elseif T <: NamedTuple
        return T(Tuple(args))
    else
        return T(args...)
    end
end

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
function _pack_mutable(binding, fields)
    e = Expr(:block, [:($binding.$f = $f) for f in fields]...)
    push!(e.args, binding)
    e
end
function _pack_new(T, fields)
    Expr(:call, T, fields...)
end

"""
This function is called by the `@with_kw` macro and does the syntax
transformation from:

```julia
@with_kw struct MM{R}
    r::R = 1000.
    a::R
end
```

into

```julia
struct MM{R}
    r::R
    a::R
    MM{R}(r,a) where {R} = new(r,a)
    MM{R}(;r=1000., a=error("no default for a")) where {R} = MM{R}(r,a) # inner kw, type-paras are required when calling
end
MM(r::R,a::R) where {R} = MM{R}(r,a) # default outer positional constructor
MM(;r=1000,a=error("no default for a")) =  MM(r,a) # outer kw, so no type-paras are needed when calling
MM(m::MM; kws...) = reconstruct(mm,kws)
MM(m::MM, di::Union{AbstractDict, Tuple{Symbol,Any}}) = reconstruct(mm, di)
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
function with_kw(typedef, mod::Module, withshow=true)
    if typedef.head==:tuple # named-tuple
        withshow==false && error("`@with_kw_noshow` not supported for named tuples")
        return with_kw_nt(typedef, mod)
    elseif typedef.head != :struct
        error("""Only works on type-defs or named tuples.
              Make sure to have a space after `@with_kw`, e.g. `@with_kw (a=1,)
              Also, make sure to use a trailing comma for single-field NamedTuples.
              """)
    end
    err1str = "Field \'"
    err2str = "\' has no default, supply it with keyword."

    inner_constructors = Any[]

    # parse a few things
    tn = typename(typedef) # the name of the type
    ismutable = typedef.args[1]
    # Returns M{...} (removes any supertypes)
    if typedef.args[2] isa Symbol
        typparas = Any[]
    elseif typedef.args[2].head==:<:
        if typedef.args[2].args[1] isa Symbol
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
    if l isa Expr && l.head == :macrocall && l.args[1] == Symbol("@deftype")
        has_deftyp = true
        if length(l.args) != 3
            error("Malformed `@deftype` line $l")
        end
        deftyp = l.args[3]
        if done(lns, i)
            error("@with_kw only supported for types which have at least one field.")
        end
    else
        has_deftyp = false
    end

    # Expand all macros (except @assert) in body now (only works at
    # top-level)
    # See issue https://github.com/mauro3/Parameters.jl/issues/21
    lns2 = Any[] # need new lines as expanded macros may have many lines
    for (i,l) in enumerate(lns) # loop over body of typedef
        if i==1 && has_deftyp
            push!(lns2, l)
            continue
        end
        if l isa Symbol || l isa String
            push!(lns2, l)
            continue
        end
        if l.head==:macrocall && l.args[1]!=Symbol("@assert")
            tmp = macroexpand(mod, l)
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
    fielddefs.args = Any[]
    kws = OrderedDict{Any, Any}()
    # assertions in the body
    asserts = Any[]
    for (i,l) in enumerate(lns) # loop over body of typedef
        if i==1 && has_deftyp
            # ignore @deftype line
            continue
        end
        if l isa Symbol  # no default value and no type annotation
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
        elseif l isa String # doc-string
            push!(fielddefs.args, l)
        elseif l.head==:(=)  # default value and with or without type annotation
            if l.args[1] isa Expr && (l.args[1].head==:call || # inner constructor
                                        l.args[1].head==:where && l.args[1].args[1].head==:call) # inner constructor with `where`
                check_inner_constructor(l)
                push!(inner_constructors, l)
            else
                fld = l.args[1]
                if fld isa Symbol && has_deftyp # no type annotation
                    fld = :($fld::$deftyp)
                end
                # add field doc-strings
                docstring = string("Default: ", l.args[2])
                if i > 1 && lns[i-1] isa String
                    # if the last line was a docstring, append the default
                    fielddefs.args[end] *= " " * docstring
                else
                    # otherwise add a new line
                    push!(fielddefs.args, docstring)
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
    typ = Expr(:struct, typedef.args[1:2]..., copy(fielddefs))

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
        innerc = :( $tn{$(tps...)}($kwargs) where {$(tps...)} = $tn{$(tps...)}($(args...)))
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
            innerc2 = :( $tn{$(tps...)}($(args...)) where {$(tps...)} = new{$(tps...)}($(args...)) )
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
        outer_positional = :(  $tn($(fielddef_strip_contT...)) where {$(typparas...)}
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
    # NOTE: The reason to have both outer and inner keyword
    # constructors are to allow both calls:
    #   `MT4(r=4, a=5.0)` (outer kwarg-constructor) and
    #   `MT4{Float32, Int}(r=4, a=5.)` (inner kwarg constructor).
    #
    # NOTE to above NOTE: this is probably not the case (anymore?),
    # as Base.@kwdef does not define inner constructors:
    # julia> Base.@kwdef struct MT4_{R,I}
    #            r::R=5
    #            a::I
    #        end
    #
    # julia> MT4_(r=4, a=5.0)
    # MT4_{Int64,Float64}(4, 5.0)
    #
    # julia> MT4_{Float32, Int}(r=4, a=5.)
    # MT4_{Float32,Int64}(4.0f0, 5)


    ## outer copy constructor
    ###
    outer_copy = quote
        $tn(pp::$tn; kws... ) = $Parameters.reconstruct(pp, kws)
        # $tn(pp::$tn, di::Union(AbstractDict,Vararg{Tuple{Symbol,Any}}) ) = reconstruct(pp, di) # see issue https://github.com/JuliaLang/julia/issues/11537
        # $tn(pp::$tn, di::Union(AbstractDict, Tuple{Vararg{Tuple{Symbol, Any}}}) ) = reconstruct(pp, di) # see issue https://github.com/JuliaLang/julia/issues/11537
        $tn(pp::$tn, di::$Parameters.AbstractDict) = $Parameters.reconstruct(pp, di)
        $tn(pp::$tn, di::Vararg{Tuple{Symbol,Any}} ) = $Parameters.reconstruct(pp, di)
    end

    # (un)pack macro from https://groups.google.com/d/msg/julia-users/IQS2mT1ITwU/hDtlV7K1elsJ
    unpack_name = Symbol("unpack_"*string(tn))
    pack!_name = Symbol("pack_"*string(tn)*"!")
    pack_name = Symbol("pack_"*string(tn))
    showfn = if withshow
        :(function Base.show(io::IO, p::$tn)
              if get(io, :compact, false) || get(io, :typeinfo, nothing)==$tn
                Base.show_default(IOContext(io, :limit => true), p)
              else
                # just dumping seems to give ok output, in particular for big data-sets:
                dump(IOContext(io, :limit => true), p, maxdepth=1)
              end
          end)
    else
        :nothing
    end
    if ismutable
        pack_macros = quote
            macro $pack!_name(ex)
                esc($Parameters._pack_mutable(ex, $unpack_vars))
            end
            macro $pack_name()
                esc($Parameters._pack_new($tn, $unpack_vars))
            end
        end
    else
        pack_macros = quote
            macro $pack_name()
                esc($Parameters._pack_new($tn, $unpack_vars))
            end
        end
    end

    # Finish up
    quote
        Base.@__doc__ $typ
        $outer_positional
        $outer_kw
        $outer_copy
        $showfn
        macro $unpack_name(ex)
            esc($Parameters._unpack(ex, $unpack_vars))
        end
        $pack_macros
        $tn
    end
end

"""
Do the with-kw stuff for named tuples.
"""
function with_kw_nt(typedef, mod)
    kwargs = []
    args = []
    nt = []
    for a in typedef.args
        if a isa Expr
            a.head != :(=) && error("NameTuple fields need to be of form: `k=val`")
            sy = a.args[1]::Symbol
            va = a.args[2]
            push!(kwargs, Expr(:kw, sy, va))
            push!(args, sy)
            push!(nt, :($sy=$sy))
        elseif a isa Symbol  # no default value given
            sy = a
            push!(args, sy)
            push!(nt, :($sy=$sy))
            push!(kwargs, Expr(:kw, sy, :(error("Supply default value for $($(string(sy)))"))))
        else
            error("Cannot parse $(string(a))")
        end
    end
    NT = gensym(:NamedTuple_kw)
    nt = Expr(:tuple, nt...)
    quote
        $NT(; $(kwargs...)) =$nt
        $NT($(args...)) = $nt
        $NT
    end
end

"""
Macro which allows default values for field types and a few other features.

Basic usage:

```julia
@with_kw struct MM{R}
    r::R = 1000.
    a::Int = 4
end
```

For more details see manual.
"""
macro with_kw(typedef)
    return esc(with_kw(typedef, __module__, true))
end

macro with_kw(args...)
    error("""Only works on type-defs or named tuples.
          Did you try to construct a NamedTuple but omitted the space between the macro and the NamedTuple?
          Do `@with_kw (a=1, b=2)` and not `@with_kw(a=1, b=2)`.
          """)
end

"""
As `@with_kw` but does not define a `show` method to avoid annoying
redefinition warnings.

```julia
@with_kw_noshow struct MM{R}
    r::R = 1000.
    a::Int = 4
end
```

For more details see manual.
"""
macro with_kw_noshow(typedef)
    return esc(with_kw(typedef, __module__, false))
end

###########
# @consts macro

"""

"""
macro consts(block)
    @assert block.head == :block
    args = block.args
    for i in eachindex(args)
        a = args[i]
        if a isa LineNumberNode
            continue
        elseif a.head == :(=)
            args[i] = Expr(:const, args[i])
        else
            error("Could not parse block")
        end
    end
    return esc(block)
end
end # module
