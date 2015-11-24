using Parameters

abstract Paras{R<:Real, I<:Integer}

@with_kw immutable PhysicalPara{R} <: Paras{R}
    rw::R = 1000.
    ri::R = 900.
    L::R = 3.34e5
    g::R = 9.81
    cw::R = 4220.
    day::R = 24*3600.
end

# create an instance with the defaults
pp = PhysicalPara{Float64}()
# make another one based on the previous one with some modifications
pp2 = PhysicalPara(pp; cw=.11e-7, rw=100.)
# make one afresh with some non-defaults
pp3 = PhysicalPara{Float32}(cw=77, day= 987)

# Custom inner constructors:
@with_kw immutable MyS{R}
    a::R = 5
    b = 4

    # Can define inner constructors as long as:
    #  - one defining all positional arguments is given
    #  - no zero-positional arguments constructor is defined (as that
    #    would clash with the keyword constructor)
    #
    # Note that the keyword constructor goes through the positional
    # constructor, thus invariants defined there will be honored.

    MyS(a,b) = (@assert a>b; new(a,b))  # The keyword constructor
                                        # calls this constructor, so
                                        # the invariant is satisfied.
    MyS(a) = MyS{R}(a, a-1) # For this provide your own outer constructor:
end
MyS{R}(a::R) = MyS{R}(a)

MyS{Int}() # MyS(5,4)
ms = MyS(3) # MyS(3,2)
MyS(ms, b=-1) # MyS(3,-1)
try
    MyS(ms, b=6) # this will fail the assertion
end

# parameter interdependence
@with_kw immutable Para{R<:Real}
    a::R = 5
    b::R
    c::R = a+b
end
pa = Para{Int}(b=7)

# Setting a default type annotation, as often the bulk of fields will
# have the same type.  The last example more compactly:
@with_kw immutable Para2{R<:Real} @deftype R
    a = 5
    b
    c = a+b
end
pa2 = Para2{Int}(b=7)
# or more pedestrian
@with_kw immutable Para3 @deftype Float64
    a = 5
    b
    c = a+b
end
pa3 = Para3(b=7)

## (Un)pack macros
#
# When working with parameters it is often convenient to unpack (and
# pack then):
function fn1(var, pa::Para)
    @unpack_Para pa # the macro is constructed during the @with_kw
                    # and called @unpack_*
    out = var + a + b
    b = 77
    @pack_Para pa # now pa.b==77
    return out, pa
end

out, pa = fn1(7, pa)

# If only a few parameters are needed, or possibly in general, it is
# more prudent to be explicit which variables are introduced into the
# local scope:

function fn2(var, pa::Para)
    @unpack pa: a, b
    out = var + a + b
    b = 77
    @pack pa: b
    return out, pa
end

out, pa = fn2(7, pa)
