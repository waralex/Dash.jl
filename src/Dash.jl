module Dash
using DashBase
import HTTP, JSON3, CodecZlib, MD5
using Sockets
using Pkg.Artifacts

include("exceptions.jl")
include("Components.jl")
include("HttpHelpers/HttpHelpers.jl")

using .HttpHelpers

export dash, Component, callback!,
enable_dev_tools!, ClientsideFunction,
run_server, PreventUpdate, no_update, @var_str,
Input, Output, State, make_handler, callback_context,
ALL, MATCH, ALLSMALLER, DashBase

include("Contexts/Contexts.jl")
include("env.jl")
include("utils.jl")
include("app.jl")
include("resources/application.jl")
include("handlers.jl")
include("server.jl")
include("init.jl")
include("components_utils/_components_utils.jl")

@doc """
    module Dash

Julia backend for [Plotly Dash](https://github.com/plotly/dash)

# Examples
```julia

using Dash
app = dash(external_stylesheets=["https://codepen.io/chriddyp/pen/bWLwgP.css"]) do
    html_div() do
        dcc_input(id="graphTitle", value="Let's Dance!", type = "text"),
        html_div(id="outputID"),
        dcc_graph(id="graph",
            figure = (
                data = [(x = [1,2,3], y = [3,2,8], type="bar")],
                layout = Dict(:title => "Graph")
            )
        )

    end
end
callback!(app, Output("outputID", "children"), Input("graphTitle","value"), State("graphTitle","type")) do value, type
    "You've entered: '\$(value)' into a '\$(type)' input control"
end
callback!(app, Output("graph", "figure"), Input("graphTitle", "value")) do value
    (
        data = [
            (x = [1,2,3], y = abs.(randn(3)), type="bar"),
            (x = [1,2,3], y = abs.(randn(3)), type="scatter", mode = "lines+markers", line = (width = 4,))
        ],
        layout = (title = value,)
    )
end
run_server(app, HTTP.Sockets.localhost, 8050)
```

""" Dash

struct ComponentsInfo
    name::String
    version::VersionNumber
end
struct BuildInfo
    dash_version ::VersionNumber
    dash_renderer_version::VersionNumber
    embedded_components::Vector{ComponentsInfo}
end

function Base.show(io::IO, ::MIME"text/plain", info::BuildInfo)
    println(io, "Based on python `dash` version: ", info.dash_version)
    println(io, "\t`dash_renderer` version: ", info.dash_renderer_version)
    println(io, "Embedded components:")
    for comp in info.embedded_components
        println(io, "\t - `", comp.name, "` : ", comp.version)
    end
end
function build_info()
    dash_meta = load_meta("dash")
    renderer_meta = load_meta("dash_renderer")
    embedded = Vector{ComponentsInfo}()
    for name in dash_meta["embedded_components"]
        meta = load_meta(name)
        push!(embedded, ComponentsInfo(name, VersionNumber(meta["version"])))
    end

    return BuildInfo(
            VersionNumber(dash_meta["version"]),
            VersionNumber(renderer_meta["version"]),
            embedded
        )
end

@place_embedded_components
const _metadata = load_all_metadata()
function __init__()
   setup_renderer_resources()
   setup_dash_resources()
end


end # module
