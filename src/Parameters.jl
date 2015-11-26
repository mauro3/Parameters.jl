# Some discussion on this:
# https://groups.google.com/forum/#!msg/julia-users/YP31LM3Qto0/ET-XjN-vQuAJ
#
# All the model parameters
#
# Consider using https://github.com/Keno/SIUnits.jl

if VERSION >= v"0.4-"
    __precompile__()
end

module Parameters
if VERSION < v"0.4.0-"
    macro __doc__(ex)
        esc(ex)
    end
else
    import Base: @__doc__
end
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

# Transforms :(a::b) -> :a
decolon2(a::Expr) = (@assert a.head==:(::);  a.args[1])
decolon2(a::Symbol) = a

# Returns the name of the type as symbol
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


## exported functions
#####################
"""
Transforms a type-instance into a dictionary.
"""
function type2dict(dt)
    di = Dict{Symbol,Any}()
    for n in @compat fieldnames(dt)
        di[n] = getfield(dt, n)
    end
    di
end

"""
Make a new instance of a type with the same values as
the input type except for the fields given in the associative
second argument or as keywords.

type A; a; b end
a = A(3,4)
b = reconstruct(a, [(:b, 99)])
"""
function reconstruct{T}(pp::T, di)
    di = !isa(di, Associative) ? Dict(di) : di
    ns = @compat fieldnames(pp)
    args = Array(Any, length(ns))
    for (i,n) in enumerate(ns)
        args[i] = get(di, n, getfield(pp, n))
    end
    T(args...)
end
reconstruct{T}(pp::T; kws...) = reconstruct(pp, kws)


# A type with fields (r,a) in variable aa becomes
# quote
#     r = aa.r
#     a = aa.a
# end
_unpack(binding, fields) = Expr(:block, [:($f = $binding.$f) for f in fields]...)
# Pack fields back into binding using reconstruct:
function _pack(binding, fields)
    kws = [Expr(:kw, f, f) for f in fields]
    :($binding = Parameters.reconstruct($binding, $(kws...)) )
end

"""
Transforms:
@with_kw immutable MM{R}
    r::R = 1000.
    a::R
end

Into

immutable MM{R}
    r::R
    a::R
    MM(r,a) = new(r,a)
    MM(;r= = 1000., a=error("no default for a") = new(r,a)
end
MM(m::MM; kws...) = reconstruct(mm,kws)
MM(m::MM, di::Union(Associative, ((Symbol,Any)...))) = reconstruct(mm, di)
macro unpack_MM(varname)
    esc(:(
    r = varname.r
    a = varname.a
    ))
end
macro pack_MM(varname)
    esc(:(
    varname = Parameters.reconstruct(varname,r=r,a=a)
    ))
end
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
    if isa(l, Expr) && l.head==:macrocall && l.args[1]==symbol("@deftype")
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

    # the vars for the unpack macro
    unpack_vars = Any[]
    # the type def
    fielddefs = quote end # holds r::R etc
    kws = OrderedDict{Any, Any}()
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
            if isa(l.args[1], Expr) && l.args[1].head==:call
                # this is an inner constructors
                if length(l.args[1].args)==1
                    error("No inner constructors with zero positional arguments allowed!")
                elseif (length(l.args[1].args)==2 #1<length(l.args[1].args)<=3
                        && isa(l.args[1].args[2], Expr)
                        && l.args[1].args[2].head==:parameters)
                    error("No inner constructors with zero positional arguments plus keyword arguments allowed!")
                end
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
        innerc = :($tn($kwargs) = $tn{$(stripsubtypes(typparas)...)}($(args...)) )
    else
        innerc = :($tn($kwargs) = $tn($(args...)) )
    end
    push!(typ.args[3].args, innerc)

    # Inner positional constructor: only make it if no inner
    # constructors are user-defined.  If one or several are defined,
    # assume that one has the standard positional signature.
    if length(inner_constructors)==0
        innerc2 = :($tn($(args...)) = new($(args...)))
        push!(typ.args[3].args, innerc2)
    else
        append!(typ.args[3].args, inner_constructors)
    end

    # Do not provide an outer keyword-constructor as the type
    # parameters need to be given explicitly anyway.

    # Outer positional constructor which does not need explicit
    # type-parameters.  Only make this constructor if
    #  (1) type parameters are used at all
    #  (2) all type parameters are used in the fields (otherwise get a
    #      "method is not callable" warning!)
    if typparas!=Any[] # condition (1)
        outer_positional = :(  $tn{$(typparas...)}($(fielddefs.args...))
                             = $tn{$(stripsubtypes(typparas)...)}($(args...)))
        # Check condition (2)
        used_paras = Any[]
        for f in fielddefs.args
            if !isa(f,Symbol) && f.head==:(::)
                push!(used_paras, f.args[2])
            end
        end
        if !issubset(stripsubtypes(typparas), used_paras)
            outer_positional = :()
        end
    else
        outer_positional = :()
    end

    ## outer copy constructor
    ###
    if VERSION < v"0.4.0-dev"
        outer_copy = quote
            $tn(pp::$tn; kws... ) = reconstruct(pp, kws)
            $tn(pp::$tn, di::Union(Associative, ((Symbol,Any)...)) ) = reconstruct(pp, di)
        end
    else
        outer_copy = quote
            $tn(pp::$tn; kws... ) = reconstruct(pp, kws)
            # $tn(pp::$tn, di::Union(Associative,Vararg{Tuple{Symbol,Any}}) ) = reconstruct(pp, di) # see issue https://github.com/JuliaLang/julia/issues/11537
            # $tn(pp::$tn, di::Union(Associative, Tuple{Vararg{Tuple{Symbol, Any}}}) ) = reconstruct(pp, di) # see issue https://github.com/JuliaLang/julia/issues/11537
            $tn(pp::$tn, di::Associative ) = reconstruct(pp, di)
            $tn(pp::$tn, di::Vararg{Tuple{Symbol,Any}} ) = reconstruct(pp, di)
        end
    end

    # (un)pack macro from https://groups.google.com/d/msg/julia-users/IQS2mT1ITwU/hDtlV7K1elsJ
    unpack_name = symbol("unpack_"*string(tn))
    pack_name = symbol("pack_"*string(tn))
    # Finish up
    quote
        Main.Parameters.@__doc__ $typ # use Parameters.@__doc__ for 0.3 compatibility
        $outer_positional
        $outer_copy
        function Base.show(io::IO, p::$tn)
            println(io, string(typeof(p)))
            for (i, var) in enumerate($unpack_vars)
                print(io, "  " * string(var) * ": $(p.(var))")
                i == length($unpack_vars) || print(io, "\n")
            end
        end
        macro $unpack_name(ex)
            esc(Parameters._unpack(ex, $unpack_vars))
        end
        macro $pack_name(ex)
            esc(Parameters._pack(ex, $unpack_vars))
        end
    end
end
macro with_kw(typedef)
    return esc(with_kw(typedef))
end

## @pack and @unpack are independent of the datatype
function parse_pack_unpack(arg)
    if isa(arg, Symbol); error("Need format `t: a, ...`") end
    h = arg.head
    if !(h==:(:) || h==:tuple); error("Need format `t: a, ...`") end
    # var-name of structure
    v = h==:tuple ? arg.args[1].args[1] : arg.args[1]
    # vars to unpack
    up = Any[]
    if h==:tuple
        append!(up, arg.args[2:end])
        push!(up, arg.args[1].args[2])
    else
        push!(up, arg.args[2])
    end
    return v, up # variable holding the structure, variables to (un)-pack
end

"""
Unpacks fields from any datatype (no need to create it with @with_kw):
type A
    a
    b
end
aa = A(3,4)
@unpack aa: a,b
# is equivalent to
a = aa.a
b = aa.b
"""
macro unpack(arg)
    v, up = parse_pack_unpack(arg)
    out = quote end
    for u in up
        push!(out.args, :($u = $v.$u))
    end
    return esc(out)
end

"""
Packs values into a datatype.  The variables need to have the same
name as the fields.  If the datatype is mutable, it will be mutated.
If immutable, a new instance is made with `reconstruct` and assigned
to the original variable.

type A
    a
    b
end
aa = A(3,4)
b = "ha"
@pack aa: b
# is equivalent to
aa.b = b
"""
macro pack(arg)
    v, up = parse_pack_unpack(arg)
    # dict to use with reconstruct:
    di = :([])
    for u in up
        push!(di.args, :($(Base.Meta.quot(u)), $u))
    end
    # assignments for mutables
    ass = quote end
    for u in up
        push!(ass.args, :($v.$u = $u))
    end
    esc(
        quote
        if isimmutable($v)
            $v = Parameters.reconstruct($v, $di)
        else
            $ass
        end
        end
    )
end

end # module
