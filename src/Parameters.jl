module Parameters
if VERSION < v"0.4.0-dev"
    using Docile
end
# for some reason @docstrings cannot be in the same if-end?!
if VERSION < v"0.4.0-dev"
    @docstrings
end
using DataStructures

# All the model parameters
#
# Consider using https://github.com/Keno/SIUnits.jl
export @with_kw, type2dict, reconstruct

## helpers
##########

# To iterate over code blocks dropping the line-number bits:
immutable Lines
    block::Expr
end
Base.start(lns::Lines) = 1
function Base.next(lns::Lines, nr)
    for i=nr:length(lns.block.args)
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

# https://groups.google.com/forum/#!msg/julia-users/YP31LM3Qto0/ET-XjN-vQuAJ
decolon2(a::Expr) = (@assert a.head==:(::);  a.args[1])
decolon2(a::Symbol) = a

function typename(typedef)
    if isa(typedef.args[2], Symbol)
        return typedef.args[2]
    elseif isa(typedef.args[2].args[1], Symbol)
        return typedef.args[2].args[1]
    else
        return typedef.args[2].args[1].args[1]
    end
end

stripsubtypes(s::Symbol) = s
function stripsubtypes(e::Expr)
    # Expr(:<:, :A, :B) => :A
    e.args[1]
end
stripsubtypes(vec::Vector) = [stripsubtypes(v) for v in vec]


## exported functions
#####################
function type2dict(dt)
    di = Dict{Symbol,Any}()
    for n in names(dt)
        di[n] = getfield(dt, n)
    end
    di
end

@doc """
    Make a new instance of a type with the same values as 
    the input type except for the fields given in the associative 
    second argument or as keywords.

    type A; a; b end
    a = A(3,4)
    b = reconstruct(a, [(:b, 99)])
    """ ->
function reconstruct{T}(pp::T, di)
    di = !isa(di, Associative) ? Dict(di) : di
    ns = names(pp)
    args = Array(Any, length(ns))
    for (i,n) in enumerate(ns)
        args[i] = get(di, n, getfield(pp, n))
    end
    T(args...)
end
reconstruct{T}(pp::T; kws...) = copyandmodify(pp, kws)

@doc """
    Transforms:
    @with_kw immutable MM{R}
        r::R = 1000.
        a::R 
    end
    
    Into
    
    @with_kw immutable MM{R}
        r::R
        a::R
        MM(;r= = 1000., a=error("no default for a") = new(r,a)
    end
    MM(m::MM; kws...) = reconstruct(mm,kws)
    MM(m::MM, di::Union(Associative, ((Symbol,Any)...))) = reconstruct(mm, di)
    """ -> 
function with_kw(typedef)
    if typedef.head!=:type
        error("only works on type-defs")
    end
    const err1str = "Field \'" 
    const err2str = "\' has no default, supply it with keyword."
    
    # type def
    typ = Expr(:type, deepcopy(typedef.args[1:2])...)
    fielddefs = quote end
    kws = OrderedDict{Any, Any}()
    for l in Lines(typedef.args[3]) # loop over body of typedef
        if isa(l, Symbol)  # no default value and no type annotation
            push!(fielddefs.args, l)
            sym = l
            syms = string(sym)
            kws[sym] = :(error($err1str * $syms * $err2str))
        elseif l.head==:(=)
            if l.args[1]==:call
                error("no inner constructors allowed!")
            end
            push!(fielddefs.args, l.args[1])
            kws[decolon2(l.args[1])] = l.args[2]
        else # no default value but with type annotation
            push!(fielddefs.args, l)
            sym = decolon2(l.args[1])
            syms = string(sym)
            kws[sym] = :(error($err1str *$syms * $err2str))
        end
    end
    push!(typ.args, deepcopy(fielddefs))
    # inner keyword constructor
    args = Any[]
    kwargs = Expr(:parameters)
    for (k,w) in kws
        push!(args, k)
        push!(kwargs.args, Expr(:kw,k,w))
    end
    tn = typename(typedef)
    innerc = :($tn() = new())
    push!(innerc.args[1].args, kwargs)
    append!(innerc.args[2].args, args)
    push!(typ.args[3].args, innerc)

    # inner positional constructor
    innerc = :($tn() = new())
    append!(innerc.args[1].args, args)
    append!(innerc.args[2].args, args)
    push!(typ.args[3].args, innerc)

    # Do not provide an outer keyword-constructor as the type
    # parameters need to be given explicitly anyway.

    # Outer positional constructor which does not need explicit
    # type-parameters.  Only make this constructor if all type
    # parameters are used in the fields.
    if isa(typ.args[2], Symbol)
        outer_positional = :($tn() = $tn())
        append!(outer_positional.args[1].args, fielddefs.args)
        append!(outer_positional.args[2].args, args)
    else        
        outer_positional = :($tn{}() = $tn{}())
        if typ.args[2].head==:<:
            typhead = typ.args[2].args[1].args[2:end]
        else
            typhead = typ.args[2].args[2:end]
        end
        append!(outer_positional.args[1].args[1].args, typhead)
        append!(outer_positional.args[2].args[1].args, stripsubtypes(typhead))
        
        append!(outer_positional.args[1].args, fielddefs.args)
        append!(outer_positional.args[2].args, args)
        # Check that all type-parameters are used in the constructor
        # function, otherwise get a "method is not callable" warning!
        used_paras = Any[]
        for f in fielddefs.args
            if !isa(f,Symbol) && f.head==:(::)
                push!(used_paras, f.args[2])
            end
        end
        if !issubset(stripsubtypes(typhead), used_paras)
            outer_positional = :()
        end
    end

    ## outer copy constructor
    ###
    outer_copy = quote
        $tn(pp::$tn; kws... ) = reconstruct(pp, kws)
        $tn(pp::$tn, di ) = reconstruct(pp, di)
    end

    quote
        $typ
        $outer_positional
        $outer_copy
    end
end

macro with_kw(typedef)
    return esc(with_kw(typedef))
end

end # module
