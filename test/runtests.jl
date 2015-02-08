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
    c
    a::Float64
end
MT2(r=4, a=5., c=6)
MT2(r=4, a=5, c="asdf")
MT2(4, "dsaf", 5)
@test_throws ErrorException MT2(r=4)
@test_throws ErrorException MT2()

@with_kw type MT3
    r::Int=5
    a::Float64
end
MT3(r=4, a=5.)
MT3(r=4, a=5)
MT3(a=5)
MT3(4,5)
@test_throws ErrorException MT3(r=4)
@test_throws ErrorException MT3()

# with type-parameters
@with_kw immutable MT4{R,I}
    r::R=5
    a::I
end
@test_throws MethodError MT4(r=4, a=5.) # need to specify type parameters
MT4{Float32, Int}(r=4, a=5.)
MT4{Float32, Int}(a=5.)
MT4{Float32, Int}(5.4, 4)  # inner positional
mt4=MT4(5.4, 4) # outer positional
@test MT4(mt4)==mt4 # outer reconstruct
@test MT4(mt4; a=77)==MT4(5.4, 77)
@test_throws ErrorException MT4{Float32, Int}()
@test_throws InexactError MT4{Float32,Int}(a=5.5)
@test_throws InexactError MT4{Float32,Int}(5.5, 5.5)

# with type-parameters 2
abstract AMT{R<:Real}
@with_kw immutable MT5{R,I<:Integer} <: AMT{R}
    r::R=5
    a::I
end
@test_throws MethodError MT5(r=4, a=5.) # need to specify type parameters
MT5{Float32, Int}(r=4, a=5.)
MT5{Float32, Int}(a=5.)
MT5{Float32, Int}(5.4, 4)  # inner positional
mt5=MT5(5.4, 4) # outer positional
@test MT5(mt5)==mt5 # outer reconstruct
@test MT5(mt5; a=77)==MT5(5.4, 77)
@test_throws ErrorException MT5{Float32, Int}()
@test_throws InexactError MT5{Float32,Int}(a=5.5)
@test_throws InexactError MT5{Float32,Int}(5.5, 5.5)

@test_throws  MethodError MT5(5., "asdf")
@test_throws  TypeError MT5( "asdf", 5)
@test_throws  TypeError MT5{Float64, String}(5., "asdf")
@test_throws  TypeError MT5{String, Int}("asdf", 6)

# with unused type parameters
@with_kw immutable MT6{R,I}
    r::R=5
    a
end

