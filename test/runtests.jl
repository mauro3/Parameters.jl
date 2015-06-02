using Parameters
using Base.Test

# parameters.jl
###############

# parameter-less
@with_kw immutable MT1
    r::Int = 4
    c = "sdaf"
end
MT1()


# parameter-less
@with_kw type MT2
    r::Int
    c
    a::Float64
end
# @show macroexpand(:(@with_kw immutable MT2
#     r::Int
#     c
#     a::Float64
# end
# ))
# @show methods(MT2)
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
@with_kw type MT5{R,I<:Integer} <: AMT{R}
    r::R=5
    a::I
end
@test_throws MethodError MT5(r=4, a=5.) # need to specify type parameters
MT5{Float32, Int}(r=4, a=5.)
MT5{Float32, Int}(a=5.)
MT5{Float32, Int}(5.4, 4)  # inner positional
mt5=MT5(5.4, 4) # outer positional
@test MT5(mt5).r==mt5.r # outer reconstruct
@test MT5(mt5).a==mt5.a # outer reconstruct
@test MT5(mt5; a=77).a==MT5(5.4, 77).a
@test MT5(mt5; a=77).r==MT5(5.4, 77).r
@test_throws ErrorException MT5{Float32, Int}()
@test_throws InexactError MT5{Float32,Int}(a=5.5)
@test_throws InexactError MT5{Float32,Int}(5.5, 5.5)

@test_throws  MethodError MT5(5., "asdf")
@test_throws  TypeError MT5( "asdf", 5)
@test_throws  TypeError MT5{Float64, String}(5., "asdf")
@test_throws  TypeError MT5{String, Int}("asdf", 6)

# user defined inner positional constructor
@with_kw immutable MT6{R,I<:Integer} <: AMT{R}
    r::R=5
    a::I
    MT6(r) = new(r,r)
    MT6(r,a) = (@assert a>r; new(r,a))
end
@test_throws MethodError MT6(r=4, a=5.) # need to specify type parameters
MT6{Float32, Int}(r=4, a=5.)
MT6{Float32, Int}(a=6.)
MT6{Float32, Int}(5.4, 6)  # inner positional
mt6=MT6(5.4, 6) # outer positional
@test MT6(mt6)==mt6 # outer reconstruct
@test MT6(mt6; a=77)==MT6(5.4, 77)
@test_throws ErrorException MT6{Float32, Int}()
@test_throws InexactError MT6{Float32,Int}(a=5.5)
@test_throws InexactError MT6{Float32,Int}(5.5, 6.5)

@test_throws  MethodError MT6(5., "asdf")
if VERSION < v"0.4.0-dev"
    @test_throws  TypeError MT6( "asdf", 5)
else
    @test_throws MethodError MT6( "asdf", 5)
end
@test_throws  TypeError MT6{Float64, String}(5., "asdf")
@test_throws  TypeError MT6{String, Int}("asdf", 6)

# user defined BAD inner positional constructor
@with_kw type MT7{R,I<:Integer} <: AMT{R}
    r::R=5
    a::I
    MT7(r) = new(r,r+8)
    # no MT7(r,a)
end
@test_throws MethodError MT7{Float32, Int}(r=4, a=5.)
# user defined BAD inner positional constructor
@test_throws ErrorException Parameters.with_kw(:(immutable MT8{R,I<:Integer} <: AMT{R}
    r::R=5
    a::I
    MT8() = new(5,6) # this would shadow the keyword constructor!
    MT8(r,a) = new(r,a)
end))
@test_throws ErrorException Parameters.with_kw(:(type MT8{R,I<:Integer} <: AMT{R}
    r::R=5
    a::I
    MT8(;a=7) = new(5,a) # this would shadow the keyword constructor!
    MT8(r,a) = new(r,a)
end))

## (Un)pack
@with_kw immutable P1
    r::Int
    c
    a::Float64
end

let
    mt = P1(r=4, a=5, c=6)
    @unpack_P1 mt
    @test r===4
    @test c===6
    @test a===5.
    r = 1
    a = 2
    c = 3
    @pack_P1 mt
    @test mt===P1(r=1, a=2, c=3)
end
