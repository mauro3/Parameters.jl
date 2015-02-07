module Parameters
if VERSION < v"0.4.0-dev"
    using Docile
    @docstrings
end

# All the model parameters
#
# Consider using https://github.com/Keno/SIUnits.jl
export Parameter, @with_kw

abstract Paras{R<:Real,I<:Integer}

# To iterate over code blocks dropping the line-number bits:
immutable Lines
    block::Expr
end
Base.start(lns::Lines) = 1
function Base.next(lns::Lines, nr)
    for i=nr:length(lns.block.args)
        if isa(lns.block.args[i], Expr) && !(lns.block.args[i].head==:line)
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
    """ -> 
function with_kw(typedef)
    

    if td.head!=:type
        error("only works on type-defs")
    end
    # type def
    typ = Expr(:type, copy(typedef.args[1:2])...)
    fielddefs = quote end
    kws = Dict{Any, Any}()
    for l in Lines(typedef.args[3]) # loop over body of typedef
        if l.head==:(=)
            if l.args[1]==:call
                error("no inner constructors allowed!")
            end
            push!(fielddefs.args, l.args[1])
            kws[decolon2(l.args[1])] = l.args[2]
        else # no default value
            push!(fielddefs.args, l.args[1])
            sym = decolon2(l.args[1])
            syms = string(sym)
            kws[sym] = :(error("Field '" *$syms * "' has no default, supply it with keyword."))
        end
    end
    push!(typ.args, fielddefs)
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

    # Do not provide an outer constructor as it is not clear how to
    # handle the type parameters.
    out = quote
        $typ
    end
    out
end

macro with_kw(typedef)
    return esc(with_kw(typedef))
end

end # module
