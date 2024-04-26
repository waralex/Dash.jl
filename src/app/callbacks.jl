dependency_id_string(id::NamedTuple) = sorted_json(id)
dependency_id_string(id::String) = sorted_json(id)

function dependency_string(dep::Dependency{Trait, String}) where {Trait}
    return "$(dep.id).$(dep.property)"
end

function dependency_string(dep::Dependency{Trait, <:NamedTuple}) where {Trait}
    id_str = replace(
        sorted_json(dep.id),
        "."=>"\\."
    )
    return "$(id_str).$(dep.property)"
end



function output_string(deps::CallbackDeps)
    if deps.multi_out
        return ".." *
        join(dependency_string.(deps.output), "...") *
        ".."
    end
    return dependency_string(deps.output[1])
end


"""
    function callback!(func::Union{Function, ClientsideFunction, String},
        app::DashApp,
        output::Union{Vector{Output}, Output},
        input::Union{Vector{Input}, Input},
        state::Union{Vector{State}, State} = []
        )

Create a callback that updates the output by calling function `func`.

# Examples

```julia
app = dash() do
    html_div() do
        dcc_input(id="graphTitle", value="Let's Dance!", type = "text"),
        dcc_input(id="graphTitle2", value="Let's Dance!", type = "text"),
        html_div(id="outputID"),
        html_div(id="outputID2")

    end
end
callback!(app, [Output("outputID2", "children"), Output("outputID", "children")],
    Input("graphTitle", "value"),
    State("graphTitle", "type")
    ) do inputValue, stateType
    return (stateType * "..." * inputValue, inputValue)
end
```
"""
function callback!(func::Union{Function, ClientsideFunction, String},
     app::DashApp,
     output::Union{Vector{<:Output}, Output},
     input::Union{Vector{<:Input}, Input},
     state::Union{Vector{<:State}, State} = State[];
     kwargs...
     )
     return _callback!(func, app, CallbackDeps(output, input, state); kwargs...)
end

"""
    function callback!(func::Union{Function, ClientsideFunction, String},
        app::DashApp,
        deps...
        )

Create a callback that updates the output by calling function `func`.
"Flat" version of `callback!` function, `deps` must be ``Output..., Input...[,State...]``

# Examples

```julia
app = dash() do
    html_div() do
        dcc_input(id="graphTitle", value="Let's Dance!", type = "text"),
        dcc_input(id="graphTitle2", value="Let's Dance!", type = "text"),
        html_div(id="outputID"),
        html_div(id="outputID2")

    end
end
callback!(app,
    Output("outputID2", "children"),
    Output("outputID", "children"),
    Input("graphTitle", "value"),
    State("graphTitle", "type")
    ) do  inputValue, stateType
    return (stateType * "..." * inputValue, inputValue)
end
```
"""
function callback!(func::Union{Function, ClientsideFunction, String},
     app::DashApp,
     deps::Dependency...;
     kwargs...
     )
     output = Output[]
     input = Input[]
     state = State[]
     _process_callback_args(deps, (output, input, state))
     return _callback!(func, app, CallbackDeps(output, input, state, length(output) > 1); kwargs...)
end

function _process_callback_args(args::Tuple{T, Vararg}, dest::Tuple{Vector{T}, Vararg}) where {T}
    push!(dest[1], args[1])
    _process_callback_args(Base.tail(args), dest)
end
function _process_callback_args(args::Tuple{}, dest::Tuple{Vector{T}, Vararg}) where {T}
end
function _process_callback_args(args::Tuple, dest::Tuple{Vector{T}, Vararg}) where {T}
    _process_callback_args(args, Base.tail(dest))
end
function _process_callback_args(args::Tuple, dest::Tuple{})
    error("The callback method must received first all Outputs, then all Inputs, then all States")
end
function _process_callback_args(args::Tuple{}, dest::Tuple{})
end


function _callback!(func::Union{Function, ClientsideFunction, String}, app::DashApp, deps::CallbackDeps;
    prevent_initial_call = nothing,
    background = false,
    interval = 1000,
    manager = nothing,
    progress = nothing,
    progress_default = nothing,
    running = nothing,
    cancel = nothing,
    cache_args_to_ignore = nothing
    )

    check_callback(func, app, deps)

    out_symbol = Symbol(output_string(deps))
    haskey(app.callbacks, out_symbol) && error("Multiple callbacks can not target the same output. Offending output: $(out_symbol)")
    callback_func = make_callback_func!(app, func, deps)
    push!(
        app.callbacks,
        out_symbol => Callback(
                callback_func,
                deps,
                isnothing(prevent_initial_call) ?
                    get_setting(app, :prevent_initial_callbacks) :
                    prevent_initial_call,
                background,
                interval
            )
        )
end


make_callback_func!(app::DashApp, func::Union{Function, ClientsideFunction}, deps::CallbackDeps) = func

function make_callback_func!(app::DashApp, func::String, deps::CallbackDeps)
    first_output = first(deps.output)
    namespace = replace("_dashprivate_$(first_output.id)", "\""=>"\\\"")
    function_name = replace("$(first_output.property)", "\""=>"\\\"")

    function_string = """
            var clientside = window.dash_clientside = window.dash_clientside || {};
            var ns = clientside["$namespace"] = clientside["$namespace"] || {};
            ns["$function_name"] = $func;
    """
    push!(app.inline_scripts, function_string)
    return ClientsideFunction(namespace, function_name)
end

function check_callback(func, app::DashApp, deps::CallbackDeps)


    isempty(deps.output) && error("The callback method requires that one or more properly formatted outputs are passed.")
    isempty(deps.input) && error("The callback method requires that one or more properly formatted inputs are passed.")


    args_count = length(deps.state) + length(deps.input)

    check_callback_func(func, args_count)

end

function check_callback_func(func::Function, args_count)
    !hasmethod(func, NTuple{args_count, Any}) && error("The arguments of the specified callback function do not align with the currently defined callback; please ensure that the arguments to `func` are properly defined.")
end
function check_callback_func(func, args_count)
end
