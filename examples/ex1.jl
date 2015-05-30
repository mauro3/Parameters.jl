using Parameters

abstract Paras{R<:Real, I<:Integer}

@with_kw immutable PhysicalPara{R} <: Paras{R}
    rw::R = 1000.
    ri::R = 900.
    k::R = 0.05
    L::R = 3.34e5
    g::R = 9.81
    cw::R = 4220.
    day::R = 24*3600.
    A::R = 2.5e-25
    alpha::R = 5/4
end

pp = PhysicalPara{Float64}()
# make another one with some modifications
pp2 = PhysicalPara(pp; cw=.11e-7, rw=100.)

# make one afresh with some non-defaults
pp3 = PhysicalPara{Float32}(alpha=77, day= 987)

# Custom inner constructors:
@with_kw immutable MyS{R}
    a::R = 5
    b = 4
    
    # Can define inner constructors as long as:
    #  - one defining all positional arguments is given
    #  - no zero-positional arguments constructor is defined (as that
    #    would clash with the keyword constructor)

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
