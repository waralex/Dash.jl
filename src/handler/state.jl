struct ChangedAsset
    url ::String
    modified ::Int
    is_css ::Bool
end
JSON3.StructTypes.StructType(::Type{ChangedAsset}) = JSON3.StructTypes.Struct()

mutable struct StateReload
    hash::Union{String, Nothing}
    hard::Bool
    changed_assets::Vector{ChangedAsset}
    task ::Union{Nothing, Task}
    StateReload(hash) = new(hash, false, ChangedAsset[], nothing)
end

mutable struct StateCache
    resources::ApplicationResources
    index_string ::String
    dependencies_json ::String
    need_recache ::Bool
    StateCache(app, registry) = new(_cache_tuple(app, registry)..., false)
end

_dep_clientside_func(func::ClientsideFunction) = func
_dep_clientside_func(func) = nothing
function _dependencies_json(app::DashApp)
    result = map(values(app.callbacks)) do callback
        (
            inputs = dependency_tuple.(callback.dependencies.input),
            state = dependency_tuple.(callback.dependencies.state),
            output = output_string(callback.dependencies),
            clientside_function = _dep_clientside_func(callback.func),
            prevent_initial_call = callback.prevent_initial_call,
            long = callback.long && (interval = callback.interval)
        )
    end
    return JSON3.write(result)
end

function _cache_tuple(app::DashApp, registry::ResourcesRegistry)
    app_resources = ApplicationResources(app, registry)
    index_string::String = index_page(app, app_resources)
    dependencies_json = _dependencies_json(app)
    return (app_resources, index_string, dependencies_json)
end

struct HandlerState
    app::DashApp
    registry::ResourcesRegistry
    cache::StateCache
    reload::StateReload
    HandlerState(app, registry = main_registry()) = new(app, registry, StateCache(app, registry), make_reload_state(app))
end

make_reload_state(app::DashApp) = get_devsetting(app, :hot_reload) ? StateReload(generate_hash()) : StateReload(nothing)

get_cache(state::HandlerState) = state.cache

function rebuild_cache!(state::HandlerState)
    cache = get_cache(state)
    (cache.resources, cache.index_string, cache.dependencies_json) = _cache_tuple(state.app, state.registry)
    cache.need_recache = false
end
