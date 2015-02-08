using Parameters



@with_kw immutable PhysicalPara{R,I} <: Paras{R,I}
    rw::R = 1000.
    ri::R = 900.
    k::R = 0.05
    L::R = 3.34e5
    g::R = 9.81
    cw::R = 4220.
    ct::R = 7.5e-8 # pressure melt coefficient
    day::R = 24*3600.
    A::R = 2.5e-25
    alpha::R = 5/4
end
# function PhysicalPara{R,I}(pp::PhysicalPara{R,I}, di) 
#     kargs = type2dict(pp)
#     for (k,w) in di
#         kargs[k] = w
#     end
#     # would be nice to avoid the kwarg constructor here for
#     # performance:
#     PhysicalPara{R,I}(kargs)
# end
function PhysicalPara{R,I}(pp::PhysicalPara{R,I}, di)
    if !isa(di,Associative)
        di = Dict(di)
    end
    ns = names(pp)
    args = Array(Any, length(ns))
    for (i,n) in enumerate(ns)
        args[i] = get(di, n, getfield(pp, n))
    end
    PhysicalPara{R,I}(args...)
end


PhysicalPara{R,I}(pp::PhysicalPara{R,I}; kws...) = PhysicalPara{R,I}(pp, kws)


function copyandmodify{T}(pp::T, di)
    di = !isa(di, Associative) ? Dict(di) : di
    ns = names(pp)
    args = Array(Any, length(ns))
    for (i,n) in enumerate(ns)
        args[i] = get(di, n, getfield(pp, n))
    end
    T(args...)
end
copyandmodify{T}(pp::T; kws...) = copyandmodify(pp, kws)

# examples
immutable A{I}
    a::I
    b::I
    c::Float64
end
a1 = A(5, 6, 5.)
a2 = copyandmodify(a1, b=7)
a3 = copyandmodify(a1, ((:a,7),)) # not using keywords is probably faster

immutable B{I}
    a::I
    b::I
    c::Vector{I}
end
b1 = B(5, 6, [5,5])
b2 = copyandmodify(deepcopy(b1), b=7) # use deepcopy to not share array c



PhysicalPara{R,I}(pp::PhysicalPara{R,I}; kws...) = PhysicalPara{R,I}(pp, kws)


pp = PhysicalPara{Float64,Int}()
                  
# @with_kw immutable DerivedPhysicalPara
#     gamma ::R = ct*cw*rw
#     kappa::R = (gamma-1)/gamma
# end
