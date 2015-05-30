# Parameters

[![Build Status](https://travis-ci.org/mauro3/Parameters.jl.svg?branch=master)](https://travis-ci.org/mauro3/Parameters.jl)

I hope to turn this into a package to handle numerical model parameter
handling.  So far only a macro which adds a keyword constructor and an
update constructor to types is implemented.  Example:

```julia
@with_kw immutable PhysicalPara{R<:Real}
    rw::R = 1000.
    ri::R = 900.
    L::R = 3.34e5
    g::R = 9.81
    cw::R = 4220.
    day::R = 24*3600.
end

# create an instance with the defaults
pp = PhysicalPara{Float64}()
# make another one with some modifications
pp2 = PhysicalPara(pp; cw=.11e-7, rw=100.)

# make one afresh with some non-defaults
pp3 = PhysicalPara{Float32}(alpha=77, day= 987)

```

See [examples/ex1.jl](examples/ex1.jl) for more details.
