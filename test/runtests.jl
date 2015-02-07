using Parameters
using Base.Test

# parameters.jl
###############

# unsupported statements
@test_throws ErrorException Parameters.with_kw(:(immutable MT1{R}
    r::R # = 1000.
    a::R # = 5/4
    MT1(r,a) = new(r,a) # inner constructor not supported
end))

# parameter-less
@with_kw immutable MT2
    r::Int
    a::Float64
end
MT2(r=4, a=5.)
MT2(r=4, a=5)
@test_throws ErrorException MT2(r=4)
@test_throws ErrorException MT2()

@with_kw immutable MT3
    r::Int=5
    a::Float64
end
MT3(r=4, a=5.)
MT3(r=4, a=5)
MT3(a=5)
@test_throws ErrorException MT3(r=4)
@test_throws ErrorException MT3()

# with type-parameters
@with_kw immutable MT4{R,I}
    a::I
    r::R=5
end
@test_throws ErrorException MT4(r=4, a=5.) # need to specify type parameters
MT4{Int, Float32}(r=4, a=5.) # need to specify type parameters
MT4{Int, Float32}(a=5.)
@test_throws InexactError MT4{Int, Float32}(a=5.5)

