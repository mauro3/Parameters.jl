using Parameters, Test, Markdown, REPL

# reconstruct
a8679 = (a=1, b=2)
ra8679 = (a=1, b=44)
@test ra8679 == reconstruct(a8679, b=44)
@test_throws ErrorException reconstruct(a8679, c=44)

a8679 = Dict(:a=>1, :b=>2)
@test Dict(:a=>1, :b=>44) == reconstruct(a8679, b=44)
@test a8679 == Dict(:a=>1, :b=>2)
@test_throws ErrorException reconstruct(a8679, c=44)

struct A8679
    a
    b
end
a8679 = A8679(1, 2)
@test A8679(1, 44) == reconstruct(a8679, b=44)
@test_throws ErrorException reconstruct(a8679, c=44)

@test reconstruct(A8679, (a=1, b=2), b=44) == A8679(1, 44)
@test reconstruct(A8679, Dict(:a=>1, :b=>2), b=44) == A8679(1, 44)
@test_throws KeyError reconstruct(A8679, Dict("a"=>1, "b"=>2), b=44) == A8679(1, 44)
@test reconstruct(typeof((a=1, b=2)), A8679(1, 2), b=44) == (a=1, b=44)
@test reconstruct(Dict{Symbol,Any}, A8679(1, 2), b=44) == Dict(:a=>1, :b=>44)

struct B8679{T}
    a::T
    b
end
a8679 = B8679(sin, 1)
@test reconstruct(B8679, a8679, a=cos) == B8679{typeof(cos)}(cos, 1)
@test_throws MethodError reconstruct(a8679, a=cos)

##########
# @with_kw
##########

"Test documentation"
@with_kw struct MT1
    "Field r"
    r::Int = 4
    "A field"
    c = "sdaf"
end
@test MT1().r==4
@test MT1().c=="sdaf"
@test "Test documentation\n" == Markdown.plain(@doc MT1)
# https://github.com/JuliaLang/julia/issues/27092 means this does not work:
# @test "A field Default: sdaf\n" == Markdown.plain(@doc MT1.c)
@test "Field r Default: 4\n" == Markdown.plain(REPL.fielddoc(MT1, :r))
@test "A field Default: sdaf\n" == Markdown.plain(REPL.fielddoc(MT1, :c))

abstract type AMT1_2 end
"Test documentation with type-parameter"
@with_kw struct MT1_2{T} <: AMT1_2
    "Field r"
    r::Int = 4
    "A field"
    c = "sdaf"
end
@test MT1_2{Int}().r==4
@test MT1_2{Int}().c=="sdaf"
@test "Test documentation with type-parameter\n" == Markdown.plain(@doc MT1_2)
const TMT1_2 = MT1_2{Int} # Julia bug https://github.com/JuliaLang/julia/issues/27656
@test "Field r Default: 4\n" == Markdown.plain(REPL.fielddoc(TMT1_2, :r))
@test "A field Default: sdaf\n" == Markdown.plain(REPL.fielddoc(TMT1_2, :c))

"Test documentation with bound type-parameter"
@with_kw struct MT1_3{T} <: AMT1_2
    "Field r"
    r::Int = 4
    "A field"
    c::T = "sdaf"
end
@test MT1_3().r==4
@test MT1_3().c=="sdaf"
@test "Test documentation with bound type-parameter\n" == Markdown.plain(@doc MT1_3)
const TMT1_3 = MT1_3{Int} # Julia bug https://github.com/JuliaLang/julia/issues/27656
@test "Field r Default: 4\n" == Markdown.plain(REPL.fielddoc(TMT1_3, :r))
@test "A field Default: sdaf\n" == Markdown.plain(REPL.fielddoc(TMT1_3, :c))


# parameter-less
@with_kw_noshow mutable struct MT2
    r::Int
    c
    a::Float64
end
MT2(r=4, a=5., c=6)
MT2(r=4, a=5, c="asdf")
MT2(4, "dsaf", 5)
@test_throws ErrorException MT2(r=4)
@test_throws ErrorException MT2()

@with_kw mutable struct MT3
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
abstract type MM1 end
abstract type MM2{T} end
@with_kw mutable struct MT3_1 <: MM1
    r::Int=5
    a::Float64
end
MT3_1(r=4, a=5.)
MT3_1(r=4, a=5)
MT3_1(a=5)
MT3_1(4,5)
@test_throws ErrorException MT3_1(r=4)
@test_throws ErrorException MT3_1()

@with_kw mutable struct MT3_2 <: MM2{Int}
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
@with_kw struct MT4{R,I}
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
abstract type AMT{R<:Real} end
@with_kw mutable struct MT5{R,I<:Integer} <: AMT{R}
    r::R=5
    a::I
end
@test_throws MethodError MT5(r=4, a=5.) # a has wrong type
MT5{Float32, Int}(r=4, a=5.)  # a gets converted
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

# with type parameters and supertype
@with_kw mutable struct MT4_1{T} <: MM1
    r::Int=5
    a::T
end
MT4_1{Float64}(r=4, a=5.)
MT4_1{Float64}(r=4, a=5)
MT4_1{Float64}(a=5)
MT4_1{Float64}(4,5)
@test_throws ErrorException MT4_1{Float64}(r=4)
@test_throws ErrorException MT4_1{Float64}()

@with_kw mutable struct MT4_2{T} <: MM2{T}
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
@with_kw struct MT6{R,I<:Integer} <: AMT{R}
    r::R=5
    a::I
    MT6{R,I}(r) where {R,I} = new{R,I}(r,r)
    MT6{R,I}(r,a) where {R,I} = (@assert a>r; new{R,I}(r,a))
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
@test_throws  TypeError MT6{Float64, String}(5., "asdf")
@test_throws  TypeError MT6{String, Int}("asdf", 6)

# user defined BAD inner positional constructor
@with_kw mutable struct MT7{R,I<:Integer} <: AMT{R}
    r::R=5
    a::I
    MT7{R,R}(r::R) where {R} = new{R,R}(r,r+8)
    # no MT7(r,a)
end
@test_throws MethodError MT7{Float32, Int}(r=4, a=5.)

# user defined BAD inner positional constructor
tmp = :(struct MT8{R,I<:Integer} <: AMT{R}
        r::R=5
        a::I
        MT8() = new{Int,Int}(5,6) # this would shadow the keyword constructor!
        MT8{R,I}(r,a) where {R,I} = new{R,I}(r,a)
        end)
@test_throws ErrorException Parameters.with_kw(tmp, @__MODULE__)
tmp = :(mutable struct MT8{R,I<:Integer} <: AMT{R}
        r::R=5
        a::I
        MT8(;a=7) = new{Int,Int}(5,a) # this would shadow the keyword constructor!
        MT8{R,I}(r,a) where {R,I} = new{R,I}(r,a)
        end)
@test_throws ErrorException Parameters.with_kw(tmp, @__MODULE__)

# default type annotation (adapted from MT6 test above)
@with_kw struct MT8{R,I<:Integer} <: AMT{R} @deftype R
    r=5
    a::I
    MT8{R,R}(r::R) where {R} = new{R,R}(r,r)
    MT8{R,I}(r,a) where {R,I} = (@assert a>r; new{R,I}(r,a))
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
@test_throws  TypeError MT8{Float64, String}(5., "asdf")
@test_throws  TypeError MT8{String, Int}("asdf", 6)
@test MT8.var.name==:R
@test MT8.body.var.name==:I
@test MT8.body.var.ub==Integer
@test MT8{Float32,Int32}.types[1]==Float32
@test MT8{Float32,Int32}.types[2]==Int32


# parameter interdependence
@with_kw struct MT9{R<:Real}
    a::R = 5
    b::R
    c::R = a+b
end
@test MT9{Float64}(b=1).c==6
@test MT9{Float64}(b=1, c=1).c==1

@with_kw struct MT10{R<:Real}
    b::R = 6
    c::R = a+b
    a::R = 5
end
@test_throws UndefVarError MT10{Float64}() # defaults are evaluated in order
@test_throws UndefVarError MT10{Float64}(b=1).c
@test MT10{Float64}(b=1, c=1).c==1

# binding outside variables
a_ = 7
b_ = [1,2]
@with_kw struct MT11
    a::Int=a_  # a::Int=a is not possible as the outside a gets shadowed
    b::Vector{Int}=b_
end
m = MT11()
@test m.a===a_
@test m.b===b_
a_ = 5
b_[1] = 2
@test m.a===7
@test m.b[1]==2

## (Un)pack
@with_kw struct P1
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
    @test_throws LoadError eval(:(@pack!_P1 mt))
    mt2 = let P1 = error  # `P1` should not be resolved in this namespace
        @pack_P1
    end
    @test mt2 === P1(r=r, c=c, a=a)
end

@with_kw mutable struct P1m
    r::Int
    c
    a::Float64
end

let
    mt = P1m(r=4, a=5, c=6)
    @unpack_P1 mt
    @test r===4
    @test c===6
    @test a===5.
    r = 1
    a = 2
    c = 3
    mt2 = let P1m = error  # `P1m` should not be resolved in this namespace
        @pack_P1m
    end
    @test (mt2.r, mt2.c, mt2.a) == (r, c, a)
    @test (mt.r, mt.c, mt.a) === (4, 6, 5.0)  # mt is unmodified
    @pack_P1m! mt
    if Int==Int64
        @test string(mt) == "P1m\n  r: Int64 1\n  c: Int64 3\n  a: Float64 2.0\n"
    else
        @test string(mt) == "P1m\n  r: Int32 1\n  c: Int32 3\n  a: Float64 2.0\n"
    end
end

### Assertions
@with_kw struct MT12
    a=5; @assert a>=5
    b
    @assert b>a
end

@test_throws AssertionError MT12(b=2)
@test_throws AssertionError MT12(a=1,b=2)
@test MT12(b=6)==MT12(5,6)

# only asserts allowed if no inner constructors
@test_throws ErrorException Parameters.with_kw(:(struct MT13
                                                   a=5;
                                                   @assert a>=5
                                                   MT13(a) = new(8)
                                                 end),
                                               @__MODULE__)

# issue #29: assertions with parameterized types
@with_kw struct MT12a{R}
    a::Array{R,1}
    @assert 1 == length(a)
end
@test_throws AssertionError MT12a([1,2])
@test MT12a([1]).a==MT12a(a=[1]).a

####
# issue 10: infer type parameters from kw-args
@with_kw struct I10{T} @deftype Int
    a::T
    b = 10
    c::T="aaa"
end
@test_throws ErrorException I10()
@test I10(1,2,3)==I10{Int}(1,2,3)
@test_throws MethodError I10(a=10) # typeof(a)!=typeof(c)
a_ = I10(a="asd")
b_ = I10{String}("asd",10,"aaa")
@test a_==b_

@with_kw struct I10a{T}
    a::T
end
@test I10a([1]).a==I10a(a=[1]).a
@test I10a(1)==I10a(a=1)
@with_kw struct I10b{T}
    a::Vector{T}
end
@test I10b([1]).a==I10b(a=[1]).a
@test_throws MethodError I10b(a=1)

# issue #12: only one-liner inner constructors were parsed correctly.
@with_kw struct T9867
    r::Int
    function T9867(r)
        new(r)
    end
end
@test_throws ErrorException T9867()
@test T9867(r=2).r == 2

# issue #56: spliced-in modules
@eval @with_kw struct SplicedModule <: $Base.AbstractVector{Int}
    x
end
@test SplicedModule(12).x == 12

# NamedTuples
###
MyNT = @with_kw (a=1, b="test", w=:uu)
@test MyNT()==(a=1, b="test", w=:uu)
@test MyNT(b=1)==(a=1, b=1, w=:uu)
@test MyNT(1,2,"a")==(a=1, b=2, w="a")
@test_throws MethodError MyNT(c=1)
@test_throws LoadError @eval @with_kw (a::Int=1,) # no type annotations allowed
@test_throws LoadError @eval @with_kw(a=1,) # no space

MyNT2 = @with_kw (a=1, b="test", w)
@test_throws ErrorException MyNT2() # no default for w

MyNT3 = @with_kw (a=1, b=a)
@test MyNT3()==(a=1, b=1)
@test MyNT3(a=2)==(a=2, b=2)
@test MyNT3(b=2)==(a=1, b=2)

@test_throws ErrorException MyNT().z # Undefined field access
q = x -> x^3
scopingTest = @with_kw (q = q,)
@test scopingTest().q(2) == 8
x = [1, 2, 3]
scopingTest = @with_kw (x = x,)
@test scopingTest().x == [1, 2, 3]
x = [1, 2, 3]
immutabilityTest = @with_kw (f = x,)
obj = immutabilityTest()
x = [4, 5, 6]
@test obj.f == [1, 2, 3] # Test immutability
@test immutabilityTest().f == [4, 5, 6] # Test rebinding for new object

# Exotic input test
naughtyInputs = ["!@#\$%^&*()`~", :"()esc(;", :x, :(eval(:x)), true, esc(true), "-9223372036854775808/-1", :(0/0), "-9223372036854775808/-1", "0xabad1dea", :(@test)]
for input in naughtyInputs
    naughtyTest = @with_kw (x = input, y = 2)
    @test naughtyTest().x == input
end

# Other behavior checks
compoundTest = @with_kw (x = (2 > 1), y = 2)
@test compoundTest().x == true # Compound evaluation check
foo(x) = 3*x
anonymousTest = @with_kw (x = x -> foo(x), y = 2)
@test anonymousTest().x(4) == 12 # Anonymous functions/value clash check
symbolTest = @with_kw (x = :x, y = 2)
@test symbolTest().x == :x

###########################
# Packing and unpacking @unpack, @pack!
##########################
# Example with dict:
d = Dict{Symbol,Any}(:a=>5.0,:b=>2,:c=>"Hi!")
@unpack a, c = d
@test a == 5.0 #true
@test c == "Hi!" #true

d = Dict("a"=>5.0,"b"=>2,"c"=>"Hi!")
@unpack a, c = d
@test a == 5.0 #true
@test c == "Hi!" #true

# Example with named tuple
@eval d = (a=5.0, b=2, c="Hi!")
@unpack a, c = d
@test a == 5.0 #true
@test c == "Hi!" #true

mutable struct PropertyExample
    a
    last_set_property
end
Base.getproperty(::PropertyExample, name::Symbol) = String(name)
Base.setproperty!(d::PropertyExample, name::Symbol, value) =
    setfield!(d, :last_set_property, (name, value))
Base.propertynames(::PropertyExample) = (:A, :B, :C)

let d = PropertyExample(:should_be_ignored, nothing)
    @unpack a, b = d
    @test a == "a"
    @test b == "b"

    a = "a value"
    @pack! d = a
    @test getfield(d, :last_set_property) == (:a, "a value")

    @test type2dict(d) == Dict(:A => "A", :B => "B", :C => "C")
end

# TODO add test with non String string

# Example with type:
mutable struct A; a; b; c; end
d = A(4,7.0,"Hi!")
@unpack a, c = d
@test a == 4 #true
@test c == "Hi!" #true

## Packing

# Example with dict:
a = 5.0
c = "Hi!"
d = Dict{Symbol,Any}()
@pack! d = a, c
@test d==Dict{Symbol,Any}(:a=>5.0,:c=>"Hi!")

d = Dict{String,Any}()
@pack! d = a, c
@test d==Dict{String,Any}("a"=>5.0,"c"=>"Hi!")


# Example with type:
a = 99
c = "HaHa"
d = A(4,7.0,"Hi")
@pack! d = a, c
@test d.a == 99
@test d.c == "HaHa"

# older tests ported
mutable struct UP1
    aUP1
    bUP1
end
uu = UP1(1,2)
@test_throws ErrorException @unpack cUP1 = uu
@test_throws ErrorException @unpack aUP1, cUP1 = uu

aUP1, bUP1 = 0, 0
@unpack aUP1 = uu
@test aUP1==1
@test bUP1==0
aUP1, bUP1 = 0, 0
@unpack aUP1, bUP1 = uu
@test aUP1==1
@test bUP1==2


vv = uu
aUP1 = 99
@pack! uu = aUP1
@test uu==vv
@test uu.aUP1==99

struct UP2
    aUP2
    bUP2
end
uu = UP2(1,2)
@test_throws ErrorException @unpack cUP2 = uu
@test_throws ErrorException @unpack aUP2, cUP2 = uu

aUP1 = 99
@test_throws ErrorException @pack! uu = aUP1

# check that inference works
struct UP3
    a::Float64
    b::Int
end
function f(u::UP3)
    @unpack a,b = u
    a,b
end
@inferred f(UP3(1,2))

#
@with_kw struct UP4{T}
    g::T=9
    a::Float64=4
end
@test typeof(UP4())==UP4{Int}
@test UP4().g===9
@test UP4().a===4.0


# Issue 21
# A macro to create the same fields in several types:
macro def(name, definition)
    return quote
        macro $(esc(name))()
            esc($(Expr(:quote, definition)))
        end
    end
end
@def sharedparams1 begin
    a::Float64  = 1.0
    b::Int = 1
end

@def sharedparams2 begin
    c::Float64  = 1.0
    d::Int = 1
end

@with_kw struct MyType1
    @sharedparams1
    @sharedparams2
end

@test MyType1()==MyType1(1,1,1,1)

@def sharedparams3 begin
    e::Float64  = 1.0
    @assert x>0  # nested macros which shouldn't be expanded are not allowed
end

@test_throws AssertionError Parameters.with_kw(:(struct MyType2
    @sharedparams1
    @sharedparams2
    @sharedparams3
end), @__MODULE__)

@def sharedparams4 begin
    e::Float64  = 1.0
    @sharedparams1 # not allowed as it will lead to nested begin-end block
end
@test_throws ErrorException Parameters.with_kw(:(struct MyType2
    @sharedparams4
end), @__MODULE__)

### New 0.6 type system
@with_kw struct V06{T} @deftype Array{I,1} where I<:Integer
    a::T
    b = [10]
    c::Vector{S} where S<:AbstractString=["aaa"]
end
V06(a=88)
V06(a=88, b=[1], c=["a"])
V06(88, [1], ["a"])

### test escaping
module TestModule

using Parameters: @unpack, @pack!, @with_kw

@with_kw mutable struct TestStruct
    x::Int = 1
    y::Float64 = 42.0
end

function test_function(z::TestStruct)
    @unpack x, y = z
    y += x
    @pack! z = y
    z
end

end

z2 = TestModule.test_function(TestModule.TestStruct(; y = 9.0))
@test z2.x == 1 && z2.y == 10.0

# issue 91
@testset "i91" begin
    function foo()
        a = @with_kw (x = 1, y = 2)
        return a
    end
    @test foo()() == (x = 1, y = 2)
    @test foo()(y=4) == (x = 1, y = 4)
end

####
# @consts
####
@consts begin
    a34 = 1
    b34 = 2.0
    d34 = sin(56)
end
@test a34 == 1
@test b34 == 2.0
@test_throws ErrorException global b34 = 1
## this test is dependent on Julia version, leave it:
# @test_warn "WARNING: redefinition of constant b34. This may fail, cause incorrect answers, or produce other errors." global b34 = 4.0
