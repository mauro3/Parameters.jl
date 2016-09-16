using Parameters
using Base.Test
using Compat
import Compat.String

# parameters.jl
###############

"Test documentation"
@with_kw immutable MT1
    r::Int = 4
    c = "sdaf"
end
MT1()
@test "Test documentation\n" == Markdown.plain(@doc MT1)

# parameter-less
@with_kw type MT2
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

# parameter-less with supertype
abstract MM1
abstract MM2{T}
@with_kw type MT3_1 <: MM1
    r::Int=5
    a::Float64
end
MT3_1(r=4, a=5.)
MT3_1(r=4, a=5)
MT3_1(a=5)
MT3_1(4,5)
@test_throws ErrorException MT3_1(r=4)
@test_throws ErrorException MT3_1()

@with_kw type MT3_2 <: MM2{Int}
    r::Int=5
    a::Float64
end
MT3_2(r=4, a=5.)
MT3_2(r=4, a=5)
MT3_2(a=5)
MT3_2(4,5)
@test_throws ErrorException MT3_2(r=4)
@test_throws ErrorException MT3_2()

# with type-parameters
@with_kw immutable MT4{R,I}
    r::R=5
    a::I
end
@test MT4(r=4, a=5.0)==MT4{Int,Float64}(4,5.0)
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
@test_throws  TypeError MT5{Float64, @compat String}(5., "asdf")
@test_throws  TypeError MT5{@compat String, Int}("asdf", 6)

# with type parameters and supertype
@with_kw type MT4_1{T} <: MM1
    r::Int=5
    a::T
end
MT4_1{Float64}(r=4, a=5.)
MT4_1{Float64}(r=4, a=5)
MT4_1{Float64}(a=5)
MT4_1{Float64}(4,5)
@test_throws ErrorException MT4_1{Float64}(r=4)
@test_throws ErrorException MT4_1{Float64}()

@with_kw type MT4_2{T} <: MM2{T}
    r::Int=5
    a::T
end
MT4_2{Float64}(r=4, a=5.)
MT4_2{Float64}(r=4, a=5)
MT4_2{Float64}(a=5)
MT4_2{Float64}(4,5)
@test_throws ErrorException MT4_2{Float64}(r=4)
@test_throws ErrorException MT4_2{Float64}()

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
@test_throws  TypeError MT6( "asdf", 5)
@test_throws  TypeError MT6{Float64, @compat String}(5., "asdf")
@test_throws  TypeError MT6{@compat String, Int}("asdf", 6)

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


# default type annotation (adapted from MT6 test above)
@with_kw immutable MT8{R,I<:Integer} <: AMT{R} @deftype R
    r=5
    a::I
    MT8(r) = new(r,r)
    MT8(r,a) = (@assert a>r; new(r,a))
end
@test_throws MethodError MT8(r=4, a=5.) # need to specify type parameters
MT8{Float32, Int}(r=4, a=5.)
MT8{Float32, Int}(a=6.)
MT8{Float32, Int}(5.4, 6)  # inner positional
mt6=MT8(5.4, 6) # outer positional
@test MT8(mt6)==mt6 # outer reconstruct
@test MT8(mt6; a=77)==MT8(5.4, 77)
@test_throws ErrorException MT8{Float32, Int}()
@test_throws InexactError MT8{Float32,Int}(a=5.5)
@test_throws InexactError MT8{Float32,Int}(5.5, 6.5)
@test_throws  MethodError MT8(5., "asdf")
@test_throws  TypeError MT8( "asdf", 5)
@test_throws  TypeError MT8{Float64, @compat String}(5., "asdf")
@test_throws  TypeError MT8{@compat String, Int}("asdf", 6)
@test MT8.types[1].name==:R
@test MT8.types[2].name==:I
@test MT8.types[2].ub==Integer
@test MT8{Float32,Int32}.types[1]==Float32
@test MT8{Float32,Int32}.types[2]==Int32


# parameter interdependence
@with_kw immutable MT9{R<:Real}
    a::R = 5
    b::R
    c::R = a+b
end
@test MT9{Float64}(b=1).c==6
@test MT9{Float64}(b=1, c=1).c==1

@with_kw immutable MT10{R<:Real}
    b::R = 6
    c::R = a+b
    a::R = 5
end
@test_throws UndefVarError MT10{Float64}() # defaults are evaluated in order
@test MT10{Float64}(b=1).c==6  # this shouldn't work but does: https://github.com/JuliaLang/julia/issues/9535#issuecomment-73717708
@test MT10{Float64}(b=1, c=1).c==1

# binding outside variables
a = 7
b = [1,2]
@with_kw immutable MT11
    aa::Int=a  # a::Int=a is not possible as the outside a gets shadowed
    bb::Vector{Int}=b
end
m = MT11()
@test m.aa===a
@test m.bb===b
a = 5
b[1] = 2
@test m.aa===7
@test m.bb[1]==2

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
    @test string(mt) == "P1\n  r: 1\n  c: 3\n  a: 2.0"
end

### Assertions
@with_kw immutable MT12
    a=5; @assert a>=5
    b
    @assert b>a
end

@test_throws AssertionError MT12(b=2)
@test_throws AssertionError MT12(a=1,b=2)
@test MT12(b=6)==MT12(5,6)

# only asserts allowed if no inner constructors
@test_throws ErrorException Parameters.with_kw(:(immutable MT13
                                                 a=5; @assert a>=5
                                                 MT13(a) = new(8)
                                                 end))

####
# issue 10: infer type parameters from kw-args

@with_kw immutable I10{T} @deftype Int
    a::T
    b = 10
    c::T="aaa"
end
@test_throws ErrorException I10()
@test I10(1,2,3)==I10{Int}(1,2,3)
@test_throws MethodError I10(a=10) # typeof(a)!=typeof(c)
a =  I10(a="asd")
b = I10{String}("asd",10,"aaa")
for fn in fieldnames(a)
    # complicated testing because of mutable T
    @test getfield(a, fn)==getfield(b, fn)
end


# issue #12: only one-liner inner constructors were parsed correctly.
@with_kw immutable T9867
    r::Int
    function T9867(r)
        new(r)
    end
end
@test_throws ErrorException T9867()
@test T9867(r=2).r == 2

###########################
# Packing and unpacking @unpack, @pack
##########################
# Example with dict:
d = Dict{Symbol,Any}(:a=>5.0,:b=>2,:c=>"Hi!")
@unpack a, c = d
@test a == 5.0 #true
@test c == "Hi!" #true


# Example with type:
type A; a; b; c; end
d = A(4,7.0,"Hi!")
@unpack a, c = d
@test a == 4 #true
@test c == "Hi!" #true


## Packing

# Example with dict:
a = 5.0
c = "Hi!"
d = Dict{Symbol,Any}()
@pack d = a, c
@test d==Dict{Symbol,Any}(:a=>5.0,:c=>"Hi!")


# Example with type:
a = 99
c = "HaHa"
d = A(4,7.0,"Hi")
@pack d = a, c
@test d.a == 99
@test d.c == "HaHa"


### Tests ported from Parameters.jl

# @unpack and @pack
type UP1
    a
    b
end
uu = UP1(1,2)
@test_throws ErrorException @unpack c = uu
@test_throws ErrorException @unpack a, c = uu

a, b = 0, 0
@unpack a = uu
@test a==1
@test b==0
a, b = 0, 0
@unpack a, b = uu
@test a==1
@test b==2


vv = uu
a = 99
@pack uu = a
@test uu==vv
@test uu.a==99

immutable UP2
    a
    b
end
uu = UP2(1,2)
@test_throws ErrorException @unpack c = uu
@test_throws ErrorException @unpack a, c = uu

a, b = 0, 0
@unpack a = uu
@test a==1
@test b==0
a, b = 0, 0
@unpack a,b = uu
@test a==1
@test b==2

a = 99
@test_throws ErrorException @pack uu = a
