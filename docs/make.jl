using Documenter, Parameters
makedocs(
    format = Documenter.HTML(
        prettyurls = get(ENV, "CI", nothing) == "true"
    ),
    sitename = "Parameters.jl",
    # pages also make the side-bar
    pages = Any[
        "index.md",
        "manual.md",
        "api.md"]
)

deploydocs(
    repo = "github.com/mauro3/Parameters.jl.git"
)
