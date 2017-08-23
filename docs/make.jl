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
