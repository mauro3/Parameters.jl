var documenterSearchIndex = {"docs":
[{"location":"api/#API","page":"API","title":"API","text":"","category":"section"},{"location":"api/","page":"API","title":"API","text":"Modules = [Parameters]","category":"page"},{"location":"api/#Parameters.Parameters","page":"API","title":"Parameters.Parameters","text":"This is a package I use to handle numerical-model parameters, thus the name. However, it should be useful otherwise too. It has two main features:\n\nkeyword type constructors with default values, and\nunpacking and packing of composite types and dicts.\n\nThe macro @with_kw which decorates a type definition to allow default values and a keyword constructor:\n\njulia> using Parameters\n\njulia> @with_kw struct A\n           a::Int = 6\n           b::Float64 = -1.1\n           c::UInt8\n       end\n\njulia> A(c=4)\nA\n  a: 6\n  b: -1.1\n  c: 4\n\nUnpacking is done with @unpack (@pack! is similar):\n\nstruct B\n    a\n    b\n    c\nend\n@unpack a, c = B(4,5,6)\n# is equivalent to\nBB = B(4,5,6)\na = BB.a\nc = BB.c\n\n\n\n\n\n","category":"module"},{"location":"api/#Parameters.reconstruct-Union{Tuple{T}, Tuple{T, Any}} where T","page":"API","title":"Parameters.reconstruct","text":"reconstruct(pp; kws...\nreconstruct(T::Type, pp; kws...)\n\nMake a new instance of a type with the same values as the input type except for the fields given in the keyword args.  Works for types, Dicts, and NamedTuples.  Can also reconstruct to another type, which is probably mostly useful for parameterised types where the parameter changes on reconstruction.\n\nNote: this is not very performant.  Check Setfield.jl for a faster & nicer implementation.\n\njulia> using Parameters\n\njulia> struct A\n           a\n           b\n       end\n\njulia> x = A(3,4)\nA(3, 4)\n\njulia> reconstruct(x, b=99)\nA(3, 99)\n\njulia> struct B{T}\n          a::T\n          b\n       end\n\njulia> y = B(sin, 1)\nB{typeof(sin)}(sin, 1)\n\njulia> reconstruct(B, y, a=cos) # note reconstruct(y, a=cos) errors!\nB{typeof(cos)}(cos, 1)\n\n\n\n\n\n","category":"method"},{"location":"api/#Parameters.type2dict-Tuple{Any}","page":"API","title":"Parameters.type2dict","text":"Transforms a type-instance into a dictionary.\n\njulia> struct T\n           a\n           b\n       end\n\njulia> type2dict(T(4,5))\nDict{Symbol,Any} with 2 entries:\n  :a => 4\n  :b => 5\n\nNote that this uses getproperty.\n\n\n\n\n\n","category":"method"},{"location":"api/#Parameters.with_kw","page":"API","title":"Parameters.with_kw","text":"This function is called by the @with_kw macro and does the syntax transformation from:\n\n@with_kw struct MM{R}\n    r::R = 1000.\n    a::R\nend\n\ninto\n\nstruct MM{R}\n    r::R\n    a::R\n    MM{R}(r,a) where {R} = new(r,a)\n    MM{R}(;r=1000., a=error(\"no default for a\")) where {R} = MM{R}(r,a) # inner kw, type-paras are required when calling\nend\nMM(r::R,a::R) where {R} = MM{R}(r,a) # default outer positional constructor\nMM(;r=1000,a=error(\"no default for a\")) =  MM(r,a) # outer kw, so no type-paras are needed when calling\nMM(m::MM; kws...) = reconstruct(mm,kws)\nMM(m::MM, di::Union{AbstractDict, Tuple{Symbol,Any}}) = reconstruct(mm, di)\nmacro unpack_MM(varname)\n    esc(quote\n    r = varname.r\n    a = varname.a\n    end)\nend\nmacro pack_MM(varname)\n    esc(quote\n    varname = Parameters.reconstruct(varname,r=r,a=a)\n    end)\nend\n\n\n\n\n\n","category":"function"},{"location":"api/#Parameters.with_kw_nt-Tuple{Any, Any}","page":"API","title":"Parameters.with_kw_nt","text":"Do the with-kw stuff for named tuples.\n\n\n\n\n\n","category":"method"},{"location":"api/#Parameters.@consts-Tuple{Any}","page":"API","title":"Parameters.@consts","text":"\n\n\n\n","category":"macro"},{"location":"api/#Parameters.@with_kw-Tuple{Any}","page":"API","title":"Parameters.@with_kw","text":"Macro which allows default values for field types and a few other features.\n\nBasic usage:\n\n@with_kw struct MM{R}\n    r::R = 1000.\n    a::Int = 4\nend\n\nFor more details see manual.\n\n\n\n\n\n","category":"macro"},{"location":"api/#Parameters.@with_kw_noshow-Tuple{Any}","page":"API","title":"Parameters.@with_kw_noshow","text":"As @with_kw but does not define a show method to avoid annoying redefinition warnings.\n\n@with_kw_noshow struct MM{R}\n    r::R = 1000.\n    a::Int = 4\nend\n\nFor more details see manual.\n\n\n\n\n\n","category":"macro"},{"location":"manual/#Parameters-manual","page":"Parameters manual","title":"Parameters manual","text":"","category":"section"},{"location":"manual/","page":"Parameters manual","title":"Parameters manual","text":"This is a manual by example (examples/ex1.jl).","category":"page"},{"location":"manual/#Types-with-default-values-and-keyword-constructors","page":"Parameters manual","title":"Types with default values & keyword constructors","text":"","category":"section"},{"location":"manual/","page":"Parameters manual","title":"Parameters manual","text":"Create a type which has default values using @with_kw:","category":"page"},{"location":"manual/","page":"Parameters manual","title":"Parameters manual","text":"using Parameters\n\n@with_kw struct PhysicalPara{R}\n    rw::R = 1000.\n    ri::R = 900.\n    L::R = 3.34e5\n    g::R = 9.81\n    cw::R = 4220.\n    day::R = 24*3600.\nend","category":"page"},{"location":"manual/","page":"Parameters manual","title":"Parameters manual","text":"Now the type can be constructed using the default values, or with non-defaults specified with keywords:","category":"page"},{"location":"manual/","page":"Parameters manual","title":"Parameters manual","text":"# Create an instance with the defaults\npp = PhysicalPara()\npp_f32 = PhysicalPara{Float32}() # the type parameter can be chosen explicitly\n# Make one with some non-defaults\npp2 = PhysicalPara(cw=77.0, day= 987.0)\n# Make another one based on the previous one with some modifications\npp3 = PhysicalPara(pp2; cw=.11e-7, rw=100.)\n# the normal positional constructor can also be used\n# (and should be used in hot inner loops)\npp4 = PhysicalPara(1,2,3,4,5,6)","category":"page"},{"location":"manual/","page":"Parameters manual","title":"Parameters manual","text":"To enforce constraints on the values, it's possible to use @asserts straight inside the type-def. (As usual, for mutables these asserts can be violated by updating the fields after type construction.)","category":"page"},{"location":"manual/","page":"Parameters manual","title":"Parameters manual","text":"@with_kw struct PhysicalPara2{R}\n    rw::R = 1000.; @assert rw>0\n    ri::R = 900.\n    @assert rw>ri # Note that the placement of assertions is not\n                  # relevant. (They are moved to the constructor.\nend","category":"page"},{"location":"manual/","page":"Parameters manual","title":"Parameters manual","text":"Parameter interdependence is possible:","category":"page"},{"location":"manual/","page":"Parameters manual","title":"Parameters manual","text":"@with_kw struct Para{R<:Real}\n    a::R = 5\n    b::R\n    c::R = a+b\nend\npa = Para(b=7)","category":"page"},{"location":"manual/","page":"Parameters manual","title":"Parameters manual","text":"Often the bulk of fields will have the same type. To help with this, a default type can be set. Using this feature, the last example (with additional field d) can be written more compactly as:","category":"page"},{"location":"manual/","page":"Parameters manual","title":"Parameters manual","text":"@with_kw struct Para2{R<:Real} @deftype R\n    a = 5\n    b\n    c = a+b\n    d::Int = 4 # adding a type overrides the @deftype\nend\npa2 = Para2(b=7)\n\n# or more pedestrian\n@with_kw struct Para3 @deftype Float64\n    a = 5\n    b\n    c = a+b\n    d::Int = 4\nend\npa3 = Para3(b=7)","category":"page"},{"location":"manual/","page":"Parameters manual","title":"Parameters manual","text":"Custom inner constructors can be defined as long as:","category":"page"},{"location":"manual/","page":"Parameters manual","title":"Parameters manual","text":"one defining all positional arguments is given\nno zero-positional arguments constructor is defined (as that would clash with the keyword constructor)\nno @asserts (as in above example) are used within the type body.","category":"page"},{"location":"manual/","page":"Parameters manual","title":"Parameters manual","text":"The keyword constructor goes through the inner positional constructor, thus invariants or any other calculation will be honored.","category":"page"},{"location":"manual/","page":"Parameters manual","title":"Parameters manual","text":"@with_kw struct MyS{R}\n    a::R = 5\n    b = 4\n    MyS{R}(a,b) where {R} = (@assert a>b; new(a,b)) #\n    MyS{R}(a) where {R} = MyS{R}(a, a-1) # For this provide your own outer constructor:\nend\nMyS(a::R) where {R} = MyS{R}(a)\n\nMyS{Int}() # MyS(5,4)\nms = MyS(3) # MyS(3,2)\nMyS(ms, b=-1) # MyS(3,-1)\ntry\n    MyS(ms, b=6) # this will fail the assertion\ncatch\nend","category":"page"},{"location":"manual/","page":"Parameters manual","title":"Parameters manual","text":"Note that two of the main reasons to have an inner constructor, assertions and simple calculations, are more easily achieved with @asserts and parameter interdependence.","category":"page"},{"location":"manual/","page":"Parameters manual","title":"Parameters manual","text":"The macro @with_kw defines a show-method which is, hopefully, more informative than the standard one. For example the printing of the first example is:","category":"page"},{"location":"manual/","page":"Parameters manual","title":"Parameters manual","text":"julia> PhysicalPara()\nPhysicalPara{Float64}\n  rw: Float64 1000.0\n  ri: Float64 900.0\n  L: Float64 334000.0\n  g: Float64 9.81\n  cw: Float64 4220.0\n  day: Float64 86400.0","category":"page"},{"location":"manual/","page":"Parameters manual","title":"Parameters manual","text":"If this show method definition is not desired, for instance because of method re-definition warnings, then use @with_kw_noshow.","category":"page"},{"location":"manual/#Named-Tuple-Support","page":"Parameters manual","title":"Named Tuple Support","text":"","category":"section"},{"location":"manual/","page":"Parameters manual","title":"Parameters manual","text":"As mentioned in the README, the @with_kw macro can be used to decorate a named tuple and produce a named tuple constructor with those defaults.","category":"page"},{"location":"manual/","page":"Parameters manual","title":"Parameters manual","text":"These named tuples can be defined as such:","category":"page"},{"location":"manual/","page":"Parameters manual","title":"Parameters manual","text":"MyNT = @with_kw (f = x -> x^3, y = 3, z = \"foo\")","category":"page"},{"location":"manual/","page":"Parameters manual","title":"Parameters manual","text":"And the constructors can be used as follows:","category":"page"},{"location":"manual/","page":"Parameters manual","title":"Parameters manual","text":"julia> MyNT(f = x -> x^2, z = :foo)\n(f = #12, y = 3, z = :foo)","category":"page"},{"location":"manual/","page":"Parameters manual","title":"Parameters manual","text":"The constructor is not type-locked:","category":"page"},{"location":"manual/","page":"Parameters manual","title":"Parameters manual","text":"julia> MyNT(f = \"x -> x^3\")\n(f = \"x -> x^3\", y = 3, z = \"foo\")","category":"page"},{"location":"manual/","page":"Parameters manual","title":"Parameters manual","text":"And these named tuples can unpacked in the usual way (see below).","category":"page"},{"location":"manual/","page":"Parameters manual","title":"Parameters manual","text":"julia> @unpack f, y, z = MyNT()\n(f = #7, y = 3, z = \"foo\")\n\njulia> f\n(::#7) (generic function with 1 method)\n\njulia> y\n3\n\njulia> z\n\"foo\"","category":"page"},{"location":"manual/","page":"Parameters manual","title":"Parameters manual","text":"Since the macro operates on a single tuple expression (as opposed to a tuple of assignment expressions),writing @with_kw(x = 1, y = :foo) will return an error suggesting you write @with_kw (x = 1, y = :foo).","category":"page"},{"location":"manual/#Blocks-of-constants","page":"Parameters manual","title":"Blocks of constants","text":"","category":"section"},{"location":"manual/","page":"Parameters manual","title":"Parameters manual","text":"Several constants can be defined like so:","category":"page"},{"location":"manual/","page":"Parameters manual","title":"Parameters manual","text":"@consts begin\n    a = 1\n    b = 2\n    c = 3\nend","category":"page"},{"location":"manual/","page":"Parameters manual","title":"Parameters manual","text":"(if you do the math, you'll need more than three constants in the block to actually save typing.)","category":"page"},{"location":"manual/#(Un)pack-macros","page":"Parameters manual","title":"(Un)pack macros","text":"","category":"section"},{"location":"manual/#@unpack-and-@pack-re-exported-from-UnPack.jl","page":"Parameters manual","title":"@unpack and @pack re-exported from UnPack.jl","text":"","category":"section"},{"location":"manual/","page":"Parameters manual","title":"Parameters manual","text":"When working with parameters, or otherwise, it is often convenient to unpack (and pack, in the case of mutable datatypes) some or all of the fields of a type.  This is often the case when passed into a function.","category":"page"},{"location":"manual/","page":"Parameters manual","title":"Parameters manual","text":"The preferred to do this is using the @unpack and @pack! macros from the package UnPack.jl.  These are generic and also work with non-@with_kw stucts, named-tuples, modules, and dictionaries. Here one example is given, for more see the README of UnPack. Define a mutable struct MPara:","category":"page"},{"location":"manual/","page":"Parameters manual","title":"Parameters manual","text":"@with_kw mutable struct MPara{R<:Real}\n    a::R = 5\n    b::R\n    c::R = a+b\nend\npa = MPara(b=7)\n\nfunction fn2(var, pa::MPara)\n    @unpack a, b = pa # equivalent to: a,b = pa.a,pa.b\n    out = var + a + b\n    b = 77\n    @pack! pa = b # equivalent to: pa.b = b\n    return out, pa\nend\n\nout, pa = fn2(7, pa)","category":"page"},{"location":"manual/","page":"Parameters manual","title":"Parameters manual","text":"Note that @unpack and @pack! can be customized on types, see UnPack.jl.","category":"page"},{"location":"manual/#The-type-specific-(un)pack-all-macros-(somewhat-dangerous)","page":"Parameters manual","title":"The type-specific (un)pack-all macros (somewhat dangerous)","text":"","category":"section"},{"location":"manual/","page":"Parameters manual","title":"Parameters manual","text":"The @with_kw macro automatically produces type-specific (un-)pack macros of form @unpack_TypeName, @pack_TypeName!, and @pack_TypeName which unpack/pack all fields:","category":"page"},{"location":"manual/","page":"Parameters manual","title":"Parameters manual","text":"function fn(var, pa::Para)\n    @unpack_Para pa # the macro is constructed during the @with_kw\n                    # and called @unpack_*\n    out = var + a + b\n    b = 77\n    @pack_Para! pa # only works with mutables\n    return out, pa\nend\n\nout, pa = fn(7, pa)","category":"page"},{"location":"manual/","page":"Parameters manual","title":"Parameters manual","text":"When needing a new instance, e.g. for immutables, use the no-bang version:","category":"page"},{"location":"manual/","page":"Parameters manual","title":"Parameters manual","text":"pa2 = @pack_Para","category":"page"},{"location":"manual/","page":"Parameters manual","title":"Parameters manual","text":"However, note that the (un-)packing macros which unpack all fields have a few pitfalls, as changing the type definition will change what local variables are available in a function using @unpack_*. Examples:","category":"page"},{"location":"manual/","page":"Parameters manual","title":"Parameters manual","text":"adding a field pi to a type would hijack Base.pi usage in any function using @unpack_*\nthe @unpack_* will shadow an input argument of the function with the same name as a type-fieldname. This I found very perplexing at times.\nthey do not work with properties, i.e. they can only pack/unpack the actual fields of types.","category":"page"},{"location":"manual/","page":"Parameters manual","title":"Parameters manual","text":"Thus, in general, it is probably better to use the @(un)pack(!) macros instead.","category":"page"},{"location":"#[Parameters.jl](https://github.com/mauro3/Parameters.jl)","page":"Parameters.jl","title":"Parameters.jl","text":"","category":"section"},{"location":"","page":"Parameters.jl","title":"Parameters.jl","text":"This is a package I use to handle numerical-model parameters, thus the name.  However, it should be useful otherwise too.  It has two main features:","category":"page"},{"location":"","page":"Parameters.jl","title":"Parameters.jl","text":"keyword type constructors with default values, and\nunpacking and packing of composite types and dicts.","category":"page"},{"location":"","page":"Parameters.jl","title":"Parameters.jl","text":"The keyword-constructor and default-values functionality will probably make it into Julia (# 10146, #533 and #6122) although probably not with all the features present in this package.  However, there is Base.@kwdef which covers many of the use cases of Parameters.jl's keyword constructor.  I suspect that this package should stay usable & useful even after this change lands in Julia. Note that keyword functions are currently slow in Julia, so these constructors should not be used in hot inner loops.  However, the normal positional constructor is also provided and could be used in performance critical code.","category":"page"},{"location":"","page":"Parameters.jl","title":"Parameters.jl","text":"NEWS.md keeps tabs on updates.","category":"page"}]
}
