const default_index = """<!DOCTYPE html>
<html>
    <head>
        {%metas%}
        <title>{%title%}</title>
        {%favicon%}
        {%css%}
    </head>
    <body>
        {%app_entry%}
        <footer>
            {%config%}
            {%scripts%}
            {%renderer%}
        </footer>
    </body>
</html>"""


"""
    struct DashApp <: Any

Dash.jl's internal representation of a Dash application.

This `struct` is not intended to be called directly; developers should create their Dash application using the `dash` function instead.
"""
mutable struct DashApp
    root_path ::String
    is_interactive ::Bool
    config ::DashConfig
    index_string ::Union{String, Nothing}
    title ::String
    layout ::Union{Nothing, Component, Function}
    devtools ::DevTools
    callbacks ::Dict{Symbol, Callback}
    inline_scripts ::Vector{String}

    DashApp(root_path, is_interactive, config, index_string, title = "Dash") =
    new(root_path, is_interactive, config, index_string, title, nothing, DevTools(dash_env(Bool, "debug", false)), Dict{Symbol, Callback}(), String[])

end

#only name, index_string and layout are available to set
function Base.setproperty!(app::DashApp, property::Symbol, value)
    property == :index_string && return set_index_string!(app, value)
    property == :layout && return set_layout!(app::DashApp, value)
    property == :title && return set_title!(app::DashApp, value)

    property in fieldnames(DashApp) && error("The property `$(property)` of `DashApp` is read-only")

    error("The property `$(property)` of `DashApp` does not exist.")
end

function set_title!(app::DashApp, title)
    setfield!(app, :title, title)
end

function set_layout!(app::DashApp, component::Union{Component,Function})
    setfield!(app, :layout, component)
end

get_layout(app::DashApp) = app.layout

function check_index_string(index_string::AbstractString)
    validate_index(
        "index_string", index_string,
        [
            "{%app_entry%}"=>r"{%app_entry%}",
            "{%config%}"=>r"{%config%}",
            "{%scripts%}"=>r"{%scripts%}"
        ]
    )
end
function set_index_string!(app::DashApp, index_string::AbstractString)
    check_index_string(index_string)
    setfield!(app, :index_string, index_string)
end

get_index_string(app::DashApp) = app.component.index_string


"""
Activate the dev tools, called by `run_server`.

If a parameter can be set by an environment variable, that is listed as:
  env: `DASH_****`
  Values provided here take precedence over environment variables.

Available dev_tools environment variables:
- `DASH_DEBUG`
- `DASH_UI`
- `DASH_PROPS_CHECK`
- `DASH_SERVE_DEV_BUNDLES`
- `DASH_HOT_RELOAD`
- `DASH_HOT_RELOAD_INTERVAL`
- `DASH_HOT_RELOAD_WATCH_INTERVAL`
- `DASH_HOT_RELOAD_MAX_RETRY`
- `DASH_SILENCE_ROUTES_LOGGING`
- `DASH_PRUNE_ERRORS`

# Arguments

- `debug::Bool` - Enable/disable all the dev tools unless overridden by the
       arguments or environment variables. Default is ``true`` when
       ``enable_dev_tools`` is called directly, and ``false`` when called
       via ``run_server``. env: ``DASH_DEBUG``.

- `dev_tools_ui::Bool` - Show the dev tools UI. env: ``DASH_UI``

- `dev_tools_props_check::Bool` - Validate the types and values of Dash
       component props. env: ``DASH_PROPS_CHECK``

- `dev_tools_serve_dev_bundles::Bool` - Serve the dev bundles. Production
    bundles do not necessarily include all the dev tools code.
    env: ``DASH_SERVE_DEV_BUNDLES``

- `dev_tools_hot_reload::Bool` - Activate hot reloading when app, assets,
    and component files change. env: ``DASH_HOT_RELOAD``

- `dev_tools_hot_reload_interval::Float64` - Interval in seconds for the
    client to request the reload hash. Default 3.
    env: ``DASH_HOT_RELOAD_INTERVAL``

- `dev_tools_hot_reload_watch_interval::Float64` - Interval in seconds for the
    server to check asset and component folders for changes.
    Default 0.5. env: ``DASH_HOT_RELOAD_WATCH_INTERVAL``

- `dev_tools_hot_reload_max_retry::Int` - Maximum number of failed reload
    hash requests before failing and displaying a pop up. Default 8.
    env: ``DASH_HOT_RELOAD_MAX_RETRY``
"""
function enable_dev_tools!(app::DashApp; debug = nothing,
            dev_tools_ui = nothing,
            dev_tools_props_check = nothing,
            dev_tools_serve_dev_bundles = nothing,
            dev_tools_hot_reload = nothing,
            dev_tools_hot_reload_interval = nothing,
            dev_tools_hot_reload_watch_interval = nothing,
            dev_tools_hot_reload_max_retry = nothing,
            dev_tools_silence_routes_logging = nothing,
            dev_tools_prune_errors = nothing)
    @env_default!(debug, Bool, true)
    setfield!(app, :devtools, DevTools(
        debug;
        ui = dev_tools_ui,
        props_check = dev_tools_props_check,
        serve_dev_bundles = dev_tools_serve_dev_bundles,
        hot_reload = dev_tools_hot_reload,
        hot_reload_interval = dev_tools_hot_reload_interval,
        hot_reload_watch_interval = dev_tools_hot_reload_watch_interval,
        hot_reload_max_retry = dev_tools_hot_reload_max_retry,
        silence_routes_logging = dev_tools_silence_routes_logging,
        prune_errors = dev_tools_prune_errors
    ))
end

get_devsetting(app::DashApp, name::Symbol) = getproperty(app.devtools, name)

get_setting(app::DashApp, name::Symbol) = getproperty(app.config, name)

get_assets_path(app::DashApp) = joinpath(app.root_path, get_setting(app, :assets_folder))

"""
    dash(;
            external_stylesheets,
            external_scripts,
            url_base_pathname,
            requests_pathname_prefix,
            routes_pathname_prefix,
            assets_folder,
            assets_url_path,
            assets_ignore,
            serve_locally,
            suppress_callback_exceptions,
            eager_loading ,
            meta_tags,
            index_string,
            assets_external_path,
            include_assets_files,
            show_undo_redo,
            compress,
            update_title
        )

Dash is a framework for building analytical web applications. No JavaScript required.

If a parameter can be set by an environment variable, that is listed as:
  env: `DASH_****`
  Values provided here take precedence over environment variables.

# Arguments
- `app_root::String` - a path, usually the current working directory, relative to which other folders are determined. Auto detected by default.
- `assets_folder::String` - a path, relative to the current working directory,
        for extra files to be used in the browser. Default `'assets'`. All .js and .css files will be loaded immediately unless excluded by `assets_ignore`, and other files such as images will be served if requested.

- `assets_url_path::String` - The local urls for assets will be:
        ``requests_pathname_prefix * assets_url_path * "/" * asset_path``
        where ``asset_path`` is the path to a file inside ``assets_folder``.
        Default ``'assets'`.

- `assets_ignore::String` - [EXPERIMENTAL] A regex, as a string to pass to ``Regex``, for
        assets to omit from immediate loading. Ignored files will still be
        served if specifically requested. You cannot use this to prevent access
        to sensitive files.
    :type assets_ignore: string

-  `assets_external_path::String` - [EXPERIMENTAL] an absolute URL from which to load assets.
        Use with ``serve_locally=false``. Dash can still find js and css to
        automatically load if you also keep local copies in your assets
        folder that Dash can index, but external serving can improve
        performance and reduce load on the Dash server.
        env: `DASH_ASSETS_EXTERNAL_PATH`

- `include_assets_files::Bool` - [EXPERIMENTAL] Default ``true``, set to ``false`` to prevent
        immediate loading of any assets. Assets will still be served if
        specifically requested. You cannot use this to prevent access
        to sensitive files.
        env: `DASH_INCLUDE_ASSETS_FILES`

- `url_base_pathname::String`: A local URL prefix to use app-wide.
        Default ``nothing``. Both `requests_pathname_prefix` and
        `routes_pathname_prefix` default to `url_base_pathname`.
        env: `DASH_URL_BASE_PATHNAME`

- `requests_pathname_prefix::String`: A local URL prefix for file requests.
        Defaults to `url_base_pathname`, and must end with
        `routes_pathname_prefix`
        env: `DASH_REQUESTS_PATHNAME_PREFIX`

- `routes_pathname_prefix::String`: A local URL prefix for JSON requests.
        Defaults to ``url_base_pathname``, and must start and end
        with ``'/'``.
        env: `DASH_ROUTES_PATHNAME_PREFIX`

- `serve_locally`: [EXPERIMENTAL] If `true` (default), assets and dependencies (Dash and Component js and css) will be served from local URLs. If `false` Dash will use CDN links where available.
        (Dash and Component js and css) will be served from local URLs.
        If ``false`` we will use CDN links where available.

- `meta_tags::Vector{Dict{String, String}}`: html <meta> tags to be added to the index page.
        Each dict should have the attributes and values for one tag, eg:
        ``Dict("name"=>"description", "content" => "My App")``

- `index_string::String`: Override the standard Dash index page.
        Must contain the correct insertion markers to interpolate various
        content into it depending on the app config and components used.
        See https://dash.plotly.com/external-resources for details.

- `external_scripts::Vector`: Additional JS files to load with the page.
        Each entry can be a String (the URL) or a Dict{String, String} with ``src`` (the URL)
        and optionally other ``<script>`` tag attributes such as ``integrity``
        and ``crossorigin``.

- `external_stylesheets::Vector`: Additional CSS files to load with the page.
        Each entry can be a String (the URL) or a Dict{String, String} with ``href`` (the URL)
        and optionally other ``<link>`` tag attributes such as ``rel``,
        ``integrity`` and ``crossorigin``.

- `suppress_callback_exceptions::Bool`: Default ``false``: check callbacks to
        ensure referenced IDs exist and props are valid. Set to ``true``
        if your layout is dynamic, to bypass these checks.
        env: `DASH_SUPPRESS_CALLBACK_EXCEPTIONS`

- `prevent_initial_callbacks::Bool`: Default ``false``: Sets the default value
        of ``prevent_initial_call`` for all callbacks added to the app.
        Normally all callbacks are fired when the associated outputs are first
        added to the page. You can disable this for individual callbacks by
        setting ``prevent_initial_call`` in their definitions, or set it
        ``true`` here in which case you must explicitly set it ``false`` for
        those callbacks you wish to have an initial call. This setting has no
        effect on triggering callbacks when their inputs change later on.

- `show_undo_redo::Bool`: Default ``false``, set to ``true`` to enable undo
        and redo buttons for stepping through the history of the app state.

- `compress::Bool`: Default ``true``, controls whether gzip is used to compress
        files and data served by HTTP.jl when supported by the client. Set to
        ``false`` to disable compression completely.

- `update_title::String`: Default ``Updating...``. Configures the document.title
        (the text that appears in a browser tab) text when a callback is being run.
        Set to '' if you don't want the document.title to change or if you
        want to control the document.title through a separate component or
        clientside callback.
"""
function dash(;
        app_root = app_root_path(),
        external_stylesheets = ExternalSrcType[],
        external_scripts  = ExternalSrcType[],
        url_base_pathname = dash_env("url_base_pathname"),
        requests_pathname_prefix = dash_env("requests_pathname_prefix"),
        routes_pathname_prefix = dash_env("routes_pathname_prefix"),
        assets_folder = "assets",
        assets_url_path = "assets",
        assets_ignore = "",
        serve_locally = true,
        suppress_callback_exceptions = dash_env(Bool, "suppress_callback_exceptions", false),
        prevent_initial_callbacks = false,
        eager_loading = false,
        meta_tags = Dict{Symbol, String}[],
        index_string = default_index,
        assets_external_path = dash_env("assets_external_path"),
        include_assets_files = dash_env(Bool, "include_assets_files", true),
        show_undo_redo = false,
        compress = true,
        update_title = "Updating..."

    )

        check_index_string(index_string)
        config = DashConfig(
            external_stylesheets,
            external_scripts,
            pathname_configs(
                url_base_pathname,
                requests_pathname_prefix,
                routes_pathname_prefix
                )...,
            assets_folder,
            lstrip(assets_url_path, '/'),
            assets_ignore,
            serve_locally,
            suppress_callback_exceptions,
            prevent_initial_callbacks,
            eager_loading,
            meta_tags,
            assets_external_path,
            include_assets_files,
            show_undo_redo,
            compress,
            update_title
        )
        result = DashApp(app_root, isinteractive(), config, index_string)
    return result
end
