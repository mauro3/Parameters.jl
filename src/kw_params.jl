using Match, NamedTuples
"""
Macro which takes assignment arguments (e.g., "a=2") and gives us a Named Tuple constructor that
(a) has those assignments as defaults, and (b) takes keyword redefinitions. 

This depends on NamedTuples.jl and Match.jl for v0.6.
"""
macro kw_params(args...)
    # Clean and parse input. 
    splits = map(args) do arg
        @match arg begin
            Expr(:(=), args, _) => (args[1], args[2])
            Expr(:tuple, args, _) => error("Extra space between macro and argument.")
            any_ => error("All arguments must be assignments")
        end
    end
    
    # Interpolation step. 
    assignments = []
    function clean(splits)
        for split in splits
            push!(assignments, (split[1], eval(split[2])))
        end 
    end
    
    # Package and return function. 
    clean(splits)
    esc(:(
    (;$(map(assignments) do pair 
    Expr(:kw, pair[1], pair[2])
    end...),) -> 
    $NamedTuples.@NT($(map(assignments) do pair 
        Expr(:kw, pair[1], pair[1])
    end...))
    ))
end