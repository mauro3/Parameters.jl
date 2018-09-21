using Documenter, Parameters
makedocs(
    format = :html,
    sitename = "Parameters.jl",
    # pages also make the side-bar
    pages = Any[
        "index.md",
        "manual.md",
        "api.md"]
)

deploydocs(
    repo = "github.com/mauro3/Parameters.jl.git",
    julia  = "1.0",
    target = "build",
    deps = nothing,
    make = nothing
)
