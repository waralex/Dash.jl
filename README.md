# Dash for Julia

[![Juila tests](https://github.com/plotly/Dash.jl/actions/workflows/jl_test.yml/badge.svg?query=branch%3Adev)](https://github.com/plotly/Dash.jl/actions/workflows/jl_test.yml?query=branch%3Adev)
[![CircleCI](https://img.shields.io/circleci/build/github/plotly/Dash.jl/dev.svg)](https://circleci.com/gh/plotly/Dash.jl/tree/dev)
[![GitHub](https://img.shields.io/github/license/plotly/Dash.jl.svg?color=dark-green)](https://github.com/plotly/Dash.jl/blob/master/LICENSE)
[![GitHub commit activity](https://img.shields.io/github/commit-activity/y/plotly/Dash.jl.svg?color=dark-green)](https://github.com/plotly/Dash.jl/graphs/contributors)

<div align="center">
  <a href="https://dash.plotly.com/project-maintenance">
    <img src="https://dash.plotly.com/assets/images/maintained-by-community.png" width="400px" alt="Maintained by the Plotly Community">
  </a>
</div>

#### Create beautiful, analytic applications in Julia

Built on top of Plotly.js, React and HTTP.jl, [Dash](https://plotly.com/dash/) ties modern UI elements like dropdowns, sliders, and graphs directly to your analytical Julia code.

Just getting started? Check out the [Dash for Julia User Guide](https://dash.plotly.com/julia)! If you can't find documentation there, then check out the unofficial [contributed examples](https://github.com/plotly/Dash.jl/issues/50) or check out source code from [demo applications](https://dash.gallery) in Python and then reference the Julia syntax style.

## Other resources

* <https://community.plotly.com/c/plotly-r-matlab-julia-net/julia/23>
* <https://discourse.julialang.org/tag/dash>

## Project Status

Julia components can be generated in tandem with Python and R components. Interested in getting involved with the project? Sponsorship is a great way to accelerate the progress of open source projects like this one; please feel free to [reach out to us](https://plotly.com/consulting-and-oem/)!

## Installation

To install the most recently released version:

```julia
pkg> add Dash
```

To install the latest (stable) development version instead:

```julia
pkg> add Dash#dev
```

## Usage

### Basic application

```julia
using Dash

app = dash(external_stylesheets = ["https://codepen.io/chriddyp/pen/bWLwgP.css"])

app.layout = html_div() do
    html_h1("Hello Dash"),
    html_div("Dash.jl: Julia interface for Dash"),
    dcc_graph(id = "example-graph",
              figure = (
                  data = [
                      (x = [1, 2, 3], y = [4, 1, 2], type = "bar", name = "SF"),
                      (x = [1, 2, 3], y = [2, 4, 5], type = "bar", name = "Montréal"),
                  ],
                  layout = (title = "Dash Data Visualization",)
              ))
end

run_server(app)
```

__then go to `http://127.0.0.1:8050` in your browser to view the Dash app!__

### Basic Callback

```julia
using Dash

app = dash(external_stylesheets = ["https://codepen.io/chriddyp/pen/bWLwgP.css"])

app.layout = html_div() do
    dcc_input(id = "my-id", value = "initial value", type = "text"),
    html_div(id = "my-div")
end

callback!(app, Output("my-div", "children"), Input("my-id", "value")) do input_value
    "You've entered $(input_value)"
end

run_server(app)
```

* You can make your Dash app interactive by registering callbacks with the `callback!` function.
* Outputs and inputs (and states, see below) of callback can be `Output`, `Input`, `State` objects or splats / vectors of this objects.
* Callback functions must have the signature ``(inputs..., states...)``, and provide a return value with the same number elements as the number of `Output`s to update.

### States and Multiple Outputs

```julia
using Dash

app = dash(external_stylesheets = ["https://codepen.io/chriddyp/pen/bWLwgP.css"])

app.layout = html_div() do
    dcc_input(id = "my-id", value = "initial value", type = "text"),
    html_div(id = "my-div"),
    html_div(id = "my-div2")
end

callback!(app,
          Output("my-div","children"),
          Output("my-div2","children"),
          Input("my-id", "value"),
          State("my-id", "type")) do input_value, state_value
    return ("You've entered $(input_value) in input with type $(state_value)",
            "You've entered $(input_value)")
end

run_server(app)
```

## Comparison with original Python syntax

### Component naming

* Python:

```python
import dash

dash.html.Div
dash.dcc.Graph
dash.dash_table.DataTable
```

* Dash.jl:

```julia
using Dash

html_div
dcc_graph
dash_datatable
```

### Component creation

Just as in Python, functions for declaring components have keyword arguments, which are the same as in Python. ``html_div(id = "my-id", children = "Simple text")``.

For components which declare `children`, two additional signatures are available:

* ``(children; kwargs..)`` and
* ``(children_maker::Function; kwargs...)``

So one can write ``html_div("Simple text", id = "my-id")`` for simple elements, or choose an abbreviated syntax with `do` syntax for complex elements:

```julia
html_div(id = "outer-div") do
    html_h1("Welcome"),
    html_div(id = "inner-div") do
        #= inner content =#
    end
end
```

### Application and layout

* Python:

```python
app = dash.Dash(external_stylesheets=["https://codepen.io/chriddyp/pen/bWLwgP.css"])

app.layout = html.Div(children=[....])
```

* Dash.jl:

```julia
app = dash(external_stylesheets = ["https://codepen.io/chriddyp/pen/bWLwgP.css"])

app.layout = html_div() do
    #= inner content =#
end
```

### Callbacks

* Python:

```python
@app.callback(Output('output', 'children'),
              Input('submit-button', 'n_clicks')],
              State('state-1', 'value'),
              State('state-2', 'value'))
def update_output(n_clicks, state1, state2):
    # logic
```

* Dash.jl:

```julia
callback!(app,
          Output("output", "children"),
          Input("submit-button", "n_clicks")],
          State("state-1", "value"),
          State("state-2", "value")) do n_clicks, state1, state2
    # logic
end
```

### JSON

Dash apps transfer data between the browser (aka the frontend) and the Julia process running the app (aka the backend) in JSON.
Dash.jl uses [JSON3.jl](https://github.com/quinnj/JSON3.jl) for JSON serialization/deserialization.

Note that JSON3.jl converts

* `Vector`s and `Tuple`s to JSON arrays
* `Dict`s and `NamedTuple`s to JSON objects
