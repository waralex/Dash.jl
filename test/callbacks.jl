import HTTP, JSON3
using Test
using Dash


@testset "callback! prevent_initial_call" begin
    #============= default ===========#
    app = dash()
    app.layout = html_div() do
            dcc_input(id = "my-id", value="initial value", type = "text"),
            html_div(id = "my-div"),
            html_div(id = "my-div2")
        end

    callback!(app, Output("my-div", "children"), Input("my-id", "value")) do value
        return value
    end
    callback!(app, Output("my-div2", "children"), Input("my-id", "value")) do value
        return value
    end

    handler = make_handler(app)
    request = HTTP.Request("GET", "/_dash-dependencies")
    resp = Dash.HttpHelpers.handle(handler, request)
    deps = JSON3.read(String(resp.body))
    @test deps[1].prevent_initial_call == false
    @test deps[2].prevent_initial_call == false

    #============= manual on single callback ===========#
    app = dash()
    app.layout = html_div() do
            dcc_input(id = "my-id", value="initial value", type = "text"),
            html_div(id = "my-div"),
            html_div(id = "my-div2")
        end

    callback!(app, Output("my-div", "children"), Input("my-id", "value"), prevent_initial_call = true) do value
        return value
    end
    callback!(app, Output("my-div2", "children"), Input("my-id", "value")) do value
        return value
    end

    handler = make_handler(app)
    request = HTTP.Request("GET", "/_dash-dependencies")
    resp = Dash.HttpHelpers.handle(handler, request)
    deps = JSON3.read(String(resp.body))
    @test deps[1].prevent_initial_call == true
    @test deps[2].prevent_initial_call == false

    #============= prevent_initial_callbacks ===========#
    app = dash(prevent_initial_callbacks = true)
    app.layout = html_div() do
            dcc_input(id = "my-id", value="initial value", type = "text"),
            html_div(id = "my-div"),
            html_div(id = "my-div2")
        end

    callback!(app, Output("my-div", "children"), Input("my-id", "value")) do value
        return value
    end
    callback!(app, Output("my-div2", "children"), Input("my-id", "value")) do value
        return value
    end

    handler = make_handler(app)
    request = HTTP.Request("GET", "/_dash-dependencies")
    resp = Dash.HttpHelpers.handle(handler, request)
    deps = JSON3.read(String(resp.body))
    @test deps[1].prevent_initial_call == true
    @test deps[2].prevent_initial_call == true

    #============= prevent_initial_callbacks + manual ===========#
    app = dash(prevent_initial_callbacks = true)
    app.layout = html_div() do
            dcc_input(id = "my-id", value="initial value", type = "text"),
            html_div(id = "my-div"),
            html_div(id = "my-div2")
        end

    callback!(app, Output("my-div", "children"), Input("my-id", "value")) do value
        return value
    end
    callback!(app, Output("my-div2", "children"), Input("my-id", "value"), prevent_initial_call = false) do value
        return value
    end

    handler = make_handler(app)
    request = HTTP.Request("GET", "/_dash-dependencies")
    resp = Dash.HttpHelpers.handle(handler, request)
    deps = JSON3.read(String(resp.body))
    @test deps[1].prevent_initial_call == true
    @test deps[2].prevent_initial_call == false

end

@testset "callback! single output" begin
    app = dash()
    app.layout = html_div() do
            dcc_input(id = "my-id", value="initial value", type = "text"),
            html_div(id = "my-div")
        end

    callback!(app, Output("my-div", "children"), Input("my-id", "value")) do value
        return value
    end
    @test length(app.callbacks) == 1
    @test haskey(app.callbacks, Symbol("my-div.children"))
    @test app.callbacks[Symbol("my-div.children")].func("test") == "test"

    handler = make_handler(app)
    request = HTTP.Request("GET", "/_dash-dependencies")
    resp = Dash.HttpHelpers.handle(handler, request)
    deps = JSON3.read(String(resp.body))

    @test length(deps) == 1
    cb = deps[1]
    @test cb.output == "my-div.children"
    @test cb.inputs[1].id == "my-id"
    @test cb.inputs[1].property == "value"
    @test :clientside_function in keys(cb)
    @test isnothing(cb.clientside_function)

    handler = Dash.make_handler(app)
    test_json = """{"output":"my-div.children","changedPropIds":["my-id.value"],"inputs":[{"id":"my-id","property":"value","value":"test"}]}"""
    request = HTTP.Request("POST", "/_dash-update-component", [], Vector{UInt8}(test_json))
    response = Dash.HttpHelpers.handle(handler, request)
    @test response.status == 200
    resp_obj = JSON3.read(String(response.body))
    @test in(:multi, keys(resp_obj))
    @test resp_obj.response.var"my-div".children == "test"

end

@testset "callback! multi output" begin
    app = dash()
    app.layout = html_div() do
            dcc_input(id = "my-id", value="initial value", type = "text"),
            html_div(id = "my-div"),
            html_div(id = "my-div2")
        end
    callback!(app, [Output("my-div","children"), Output("my-div2","children")], Input("my-id","value"), State("my-id","type")) do value, state
        return value, state
    end
    @test length(app.callbacks) == 1
    @test haskey(app.callbacks, Symbol("..my-div.children...my-div2.children.."))
    @test app.callbacks[Symbol("..my-div.children...my-div2.children..")].func("value", "state") == ("value", "state")

    handler = Dash.make_handler(app)
    test_json = """{"output":"..my-div.children...my-div2.children..","changedPropIds":["my-id.value"],"inputs":[{"id":"my-id","property":"value","value":"test"}], "state":[{"id":"my-id","property":"type","value":"state"}]}"""
    request = HTTP.Request("POST", "/_dash-update-component", [], Vector{UInt8}(test_json))
    response = Dash.HttpHelpers.handle(handler, request)
    @test response.status == 200
    resp_obj = JSON3.read(String(response.body))
    @test in(:multi, keys(resp_obj))
    @test resp_obj.response[Symbol("my-div")].children == "test"
    @test resp_obj.response[Symbol("my-div2")].children == "state"

    app = dash()
    app.layout = html_div() do
            dcc_input(id = "my-id", value="initial value", type = "text"),
            html_div(id = "my-div"),
            html_div(id = "my-div2")
        end
    callback!(app, [Output("my-div","children")], Input("my-id","value"), State("my-id","type")) do value, state
        return (value,)
    end
    @test length(app.callbacks) == 1
    @test haskey(app.callbacks, Symbol("..my-div.children.."))
    @test app.callbacks[Symbol("..my-div.children..")].func("value", "state") == ("value", )

    handler = Dash.make_handler(app)
    test_json = """{"output":"..my-div.children..","changedPropIds":["my-id.value"],"inputs":[{"id":"my-id","property":"value","value":"test"}], "state":[{"id":"my-id","property":"type","value":"state"}]}"""
    request = HTTP.Request("POST", "/_dash-update-component", [], Vector{UInt8}(test_json))
    response = Dash.HttpHelpers.handle(handler, request)
    @test response.status == 200
    resp_obj = JSON3.read(String(response.body))
    @test in(:multi, keys(resp_obj))
    @test resp_obj.response[Symbol("my-div")].children == "test"

end
@testset "callback! multi output flat" begin
    app = dash()
    app.layout = html_div() do
            dcc_input(id = "my-id", value="initial value", type = "text"),
            dcc_input(id = "my-id2", value="initial value", type = "text"),
            html_div(id = "my-div"),
            html_div(id = "my-div2")
        end
    callback!(app, Output("my-div","children"), Output("my-div2","children"),
                   Input("my-id","value"), Input("my-id", "value"), State("my-id","type")) do value, value2, state
        return value * value2, state
    end
    @test length(app.callbacks) == 1
    @test haskey(app.callbacks, Symbol("..my-div.children...my-div2.children.."))
    @test app.callbacks[Symbol("..my-div.children...my-div2.children..")].func("value", " value2", "state") == ("value value2", "state")

    app = dash()
    app.layout = html_div() do
            dcc_input(id = "my-id", value="initial value", type = "text"),
            dcc_input(id = "my-id2", value="initial value", type = "text"),
            html_div(id = "my-div"),
            html_div(id = "my-div2")
        end
    callback!(app, Output("my-div","children"),
                   Input("my-id","value"), Input("my-id", "value")) do value, value2
        return value * value2
    end
    @test length(app.callbacks) == 1
    @test haskey(app.callbacks, Symbol("my-div.children"))
    @test app.callbacks[Symbol("my-div.children")].func("value", " value2") == "value value2"

end
@testset "callback! multi output same component id" begin
    app = dash()
    app.layout = html_div() do
            dcc_input(id = "input-one",
                      placeholder = "text or number?")
            dcc_input(id = "input-two",
                      placeholder = "")
        end
    callback!(app, Output("input-two","placeholder"), Output("input-two","type"),
                   Input("input-one","value")) do val1
        if val1 in ["text", "number"]
            return "$val1 ??", val1
        end
        return "invalid", nothing
    end
    @test length(app.callbacks) == 1
    @test haskey(app.callbacks, Symbol("..input-two.placeholder...input-two.type.."))
    @test app.callbacks[Symbol("..input-two.placeholder...input-two.type..")].func("text") == ("text ??", "text")
    @test Dash.process_callback_call(app,
            Symbol("..input-two.placeholder...input-two.type.."),
            [(id = "input-two", property = "placeholder"),
             (id = "input-two", property = "type")],
            [(value = "text",)], [])[:response] == Dict("input-two" => Dict(:type => "text",
                                                                            :placeholder => "text ??"))

end
@testset "callback! checks" begin

    app = dash()

    app.layout = html_div() do
            dcc_input(id = "my-id", value="initial value", type = "text"),
            html_div(id = "my-div"),
            html_div(id = "my-div2")
        end

    callback!(app, Output("my-div","children"), Input("my-id","value")) do value
        return value
    end
    callback!(app, Output("my-div2","children"), Input("my-id","value")) do value
        return "v_$(value)"
    end

    @test length(app.callbacks) == 2
    @test haskey(app.callbacks, Symbol("my-div.children"))
    @test haskey(app.callbacks, Symbol("my-div2.children"))
    @test app.callbacks[Symbol("my-div.children")].func("value") == "value"
    @test app.callbacks[Symbol("my-div2.children")].func("value") == "v_value"


    #empty input
    @test_throws ErrorException callback!(app,
        [Output("my-id","value"), Output("my-div","children")],
        Input[]) do value
        return "v_$(value)"
    end


    app = dash()

    app.layout = html_div() do
            dcc_input(id = "my-id", value="initial value", type = "text"),
            dcc_input(id = "my-id2", value="initial value", type = "text"),
            html_div(id = "my-div"),
            html_div(id = "my-div2")
        end
    #empty output
    @test_throws ErrorException callback!(app,
        Input("my-id","value")) do value
        return "v_$(value)"
    end
    #empty input
    @test_throws ErrorException callback!(app,
        Output("my-div2", "children")) do value
        return "v_$(value)"
    end

    #wrong args order
    @test_throws ErrorException callback!(app,
        Input("my-id","value"), Output("my-div", "children")) do value
        return "v_$(value)"
    end

    @test_throws ErrorException callback!(app,
        Output("my-div2", "children"), Input("my-id","value"), Output("my-div", "children")) do value
        return "v_$(value)"
    end

    @test_throws ErrorException callback!(app,
        Output("my-div2", "children"), Input("my-id","value"), State("my-div", "children"), Input("my-id2", "value")) do value, value2
        return "v_$(value)"
    end

end

@testset "multiple callbacks targeting same output" begin
    app = dash()

    app.layout = html_div() do
            dcc_input(id = "my-id", value="initial value", type = "text"),
            dcc_input(id = "my-id2", value="initial value2", type = "text"),
            html_div(id = "my-div")
        end

    callback!(app, Output("my-div","children"), Input("my-id","value")) do value
        return value
    end

    testresult = @test_throws ErrorException callback!(app, Output("my-div","children"), Input("my-id2","value")) do value
        return "v_$(value)"
    end
    @test testresult.value.msg == "Multiple callbacks can not target the same output. Offending output: my-div.children"
end

@testset "empty triggered params" begin
    app = dash()
    app.layout = html_div() do
            dcc_input(id = "test-in", value="initial value", type = "text"),
            html_div(id = "test-out")
        end

    callback!(app, Output("test-out", "children"), Input("test-out", "value")) do value
        context = callback_context()
        @test length(context.triggered) == 0
        @test isempty(context.triggered)
        return string(value)
    end
    @test length(app.callbacks) == 1

    handler = Dash.make_handler(app)
    request = (
        output = "test-out.children",
        changedPropIds = [],
        inputs = [
            (id = "test-in", property = "value", value = "test")
        ]
    )
    test_json = JSON3.write(request)
    request = HTTP.Request("POST", "/_dash-update-component", [], Vector{UInt8}(test_json))
    response = Dash.HttpHelpers.handle(handler, request)

    @test response.status == 200

end
@testset "pattern-match" begin
    app = dash()
    app.layout = html_div() do
            dcc_input(id = (type="test", index = 1), value="initial value", type = "text"),
            dcc_input(id = (type="test", index = 2), value="initial value", type = "text"),
            html_div(id = (type = "test-out", index = 1)),
            html_div(id = (type = "test-out", index = 2))
        end

    changed_key = """{"index":2,"type":"test"}.value"""
    callback!(app, Output((type = "test-out", index = MATCH), "children"), Input((type="test", index = MATCH), "value")) do value
        context = callback_context()
        @test haskey(context.inputs, changed_key)
        @test context.inputs[changed_key] == "test"
        @test length(context.triggered) == 1
        @test context.triggered[1].prop_id == changed_key
        @test context.triggered[1].value == "test"
        return string(value)
    end
    @test length(app.callbacks) == 1
    out_key = Symbol("""{"index":["MATCH"],"type":"test-out"}.children""")
    @test haskey(app.callbacks, out_key)

    handler = Dash.make_handler(app)
    request = (
        output = string(out_key),
        outputs = (id = (index = 1, type="test_out"), property = "children"),
        changedPropIds = [changed_key],
        inputs = [
            (id = (index=2, type="test"), property = "value", value = "test")
        ]
    )
    test_json = JSON3.write(request)
    request = HTTP.Request("POST", "/_dash-update-component", [], Vector{UInt8}(test_json))
    response = Dash.HttpHelpers.handle(handler, request)

    @test response.status == 200
    resp_obj = JSON3.read(String(response.body))
    @test in(:multi, keys(resp_obj))
    @test resp_obj.response.var"{\"index\":1,\"type\":\"test_out\"}".children == "test"

end

@testset "pattern-match ALL single out" begin
    app = dash()
    app.layout = html_div() do
            dcc_input(id = (type="test", index = 1), value="initial value", type = "text"),
            dcc_input(id = (type="test", index = 2), value="initial value", type = "text"),
            html_div(id = (type = "test-out", index = 1)),
            html_div(id = (type = "test-out", index = 2))
        end

    first_key = """{"index":1,"type":"test"}.value"""
    changed_key = """{"index":2,"type":"test"}.value"""
    callback!(app, Output((type = "test-out", index = ALL), "children"), Input((type="test", index = ALL), "value")) do value
        context = callback_context()
        @test haskey(context.inputs, first_key)
        @test context.inputs[first_key] == "test 1"
        @test haskey(context.inputs, changed_key)
        @test context.inputs[changed_key] == "test"
        @test length(context.triggered) == 1
        @test context.triggered[1].prop_id == changed_key
        @test context.triggered[1].value == "test"
        return value
    end
    @test length(app.callbacks) == 1
    out_key = Symbol("""{"index":["ALL"],"type":"test-out"}.children""")
    @test haskey(app.callbacks, out_key)

    handler = Dash.make_handler(app)
    request = (
        output = string(out_key),
        outputs = [
                (id = (index=1, type="test-out"), property = "children"),
                (id = (index=2, type="test-out"), property = "children")
        ],
        changedPropIds = [changed_key],
        inputs = [
            [
                (id = (index=1, type="test"), property = "value", value = "test 1"),
                (id = (index=2, type="test"), property = "value", value = "test")
            ]
        ]
    )
    test_json = JSON3.write(request)
    request = HTTP.Request("POST", "/_dash-update-component", [], Vector{UInt8}(test_json))
    response = Dash.HttpHelpers.handle(handler, request)
    @test response.status == 200
    s = String(response.body)
    resp_obj = JSON3.read(s)
    @test in(:multi, keys(resp_obj))

    @test resp_obj.response.var"{\"index\":1,\"type\":\"test-out\"}".children =="test 1"
    @test resp_obj.response.var"{\"index\":2,\"type\":\"test-out\"}".children =="test"

end
@testset "pattern-match ALL multi out" begin
    app = dash()
    app.layout = html_div() do
            dcc_input(id = (type="test", index = 1), value="initial value", type = "text"),
            dcc_input(id = (type="test", index = 2), value="initial value", type = "text"),
            html_div(id = (type = "test-out", index = 1)),
            html_div(id = (type = "test-out", index = 2))
        end

    first_key = """{"index":1,"type":"test"}.value"""
    changed_key = """{"index":2,"type":"test"}.value"""
    callback!(app, [Output((type = "test-out", index = ALL), "children")], Input((type="test", index = ALL), "value")) do value
        context = callback_context()
        @test haskey(context.inputs, first_key)
        @test context.inputs[first_key] == "test 1"
        @test haskey(context.inputs, changed_key)
        @test context.inputs[changed_key] == "test"
        @test length(context.triggered) == 1
        @test context.triggered[1].prop_id == changed_key
        @test context.triggered[1].value == "test"
        return [value]
    end
    @test length(app.callbacks) == 1
    out_key = Symbol("""..{"index":["ALL"],"type":"test-out"}.children..""")
    @test haskey(app.callbacks, out_key)

    handler = Dash.make_handler(app)
    request = (
        output = string(out_key),
        outputs = [[
                (id = (index=1, type="test-out"), property = "children"),
                (id = (index=2, type="test-out"), property = "children")
        ]],
        changedPropIds = [changed_key],
        inputs = [
            [
                (id = (index=1, type="test"), property = "value", value = "test 1"),
                (id = (index=2, type="test"), property = "value", value = "test")
            ]
        ]
    )
    test_json = JSON3.write(request)
    request = HTTP.Request("POST", "/_dash-update-component", [], Vector{UInt8}(test_json))
    response = Dash.HttpHelpers.handle(handler, request)
    @test response.status == 200
    resp_obj = JSON3.read(String(response.body))
    @test in(:multi, keys(resp_obj))

    @test resp_obj.response.var"{\"index\":1,\"type\":\"test-out\"}".children =="test 1"
    @test resp_obj.response.var"{\"index\":2,\"type\":\"test-out\"}".children =="test"

end

@testset "invalid multi out" begin
    app = dash()
    app.layout = html_div() do
        html_div(id="a"),
        html_div(id="b"),
        html_div(id="c"),
        html_div(id="d"),
        html_div(id="e"),
        html_div(id="f")
    end

    callback!(app, [Output("b", "children")], Input("a", "children")) do a
        return (1,2)
    end

    #invalid number of outputs
    @test_throws Dash.InvalidCallbackReturnValue Dash.process_callback_call(app, :var"..b.children..", [(id = "b", property = "children")], [(value = "aaa",)], [])

    callback!(app, Output("c", "children"), Output("d", "children"), Input("a", "children")) do a
        return 1
    end
    #result not array
    @test_throws Dash.InvalidCallbackReturnValue Dash.process_callback_call(
            app, Symbol("..c.children...d.children.."),
            [(id = "b", property = "children")], [(value = "aaa",)], []
            )

    app = dash()
    app.layout = html_div() do
        html_div(id=(index = 1,)),
        html_div(id=(index = 2,)),
        html_div(id=(index = 3,))
    end

    callback!(app, Output((index = ALL,), "children"), Input((index = ALL,), "css")) do inputs
        return [1,2]
    end

    #pattern-match output elements length not match to specs
    @test_throws Dash.InvalidCallbackReturnValue Dash.process_callback_call(
            app, Symbol("""{"index":["ALL"]}.children"""),
            [[
                (id = """{"index":1}""", property = "children"),
                (id = """{"index":2}""", property = "children"),
                (id = """{"index":3}""", property = "children"),
            ]],
            [[(value = "aaa",), (value = "bbb",), (value = "ccc",)]], []
            )


    app = dash()
    app.layout = html_div() do
        html_div(id=(index = 1,)),
        html_div(id=(index = 2,)),
        html_div(id=(index = 3,))
    end

    callback!(app, Output((index = ALL,), "children"), Input((index = ALL,), "css")) do inputs
        return 1
    end

    #pattern-match output element not array
    @test_throws Dash.InvalidCallbackReturnValue Dash.process_callback_call(
            app, Symbol("""{"index":["ALL"]}.children"""),
            [[
                (id = """{"index":1}""", property = "children"),
                (id = """{"index":2}""", property = "children"),
                (id = """{"index":3}""", property = "children"),
            ]],
            [[(value = "aaa",), (value = "bbb",), (value = "ccc",)]], []
            )
end



@testset "clientside callbacks function" begin
    app = dash()
    app.layout = html_div() do
            dcc_input(id = "my-id", value="initial value", type = "text"),
            html_div(id = "my-div")
        end

    callback!(ClientsideFunction("namespace", "func_name"),app, Output("my-div","children"), Input("my-id","value"))

    @test length(app.callbacks) == 1
    @test haskey(app.callbacks, Symbol("my-div.children"))
    @test app.callbacks[Symbol("my-div.children")].func isa ClientsideFunction
    @test app.callbacks[Symbol("my-div.children")].func.namespace == "namespace"
    @test app.callbacks[Symbol("my-div.children")].func.function_name == "func_name"


    handler = make_handler(app)
    request = HTTP.Request("GET", "/_dash-dependencies")
    resp = Dash.HttpHelpers.handle(handler, request)
    deps = JSON3.read(String(resp.body))

    @test length(deps) == 1
    cb = deps[1]
    @test cb.output == "my-div.children"
    @test cb.inputs[1].id == "my-id"
    @test cb.inputs[1].property == "value"
    @test :clientside_function in keys(cb)
    @test cb.clientside_function.namespace == "namespace"
    @test cb.clientside_function.function_name == "func_name"
end
@testset "clientside callbacks string" begin
    app = dash()
    app.layout = html_div() do
            dcc_input(id = "my-id", value="initial value", type = "text"),
            html_div(id = "my-div")
        end

    callback!(
        """
        function(input_value) {
            return (
                parseFloat(input_value_1, 10)
            );
        }
        """
        , app,
        Output("my-div", "children"),
        Input("my-id", "value")
        )

    @test length(app.callbacks) == 1
    @test haskey(app.callbacks, Symbol("my-div.children"))
    @test app.callbacks[Symbol("my-div.children")].func isa ClientsideFunction
    @test app.callbacks[Symbol("my-div.children")].func.namespace == "_dashprivate_my-div"
    @test app.callbacks[Symbol("my-div.children")].func.function_name == "children"
    @test length(app.inline_scripts) == 1
    @test occursin("clientside[\"_dashprivate_my-div\"]", app.inline_scripts[1])
    @test occursin("ns[\"children\"]", app.inline_scripts[1])

    handler = make_handler(app)
    request = HTTP.Request("GET", "/_dash-dependencies")
    resp = Dash.HttpHelpers.handle(handler, request)
    deps = JSON3.read(String(resp.body))

    @test length(deps) == 1
    cb = deps[1]
    @test cb.output == "my-div.children"
    @test cb.inputs[1].id == "my-id"
    @test cb.inputs[1].property == "value"
    @test :clientside_function in keys(cb)
    @test cb.clientside_function.namespace == "_dashprivate_my-div"
    @test cb.clientside_function.function_name == "children"
    request = HTTP.Request("GET", "/")
    resp = Dash.HttpHelpers.handle(handler, request)
    body = String(resp.body)
    @test occursin("clientside[\"_dashprivate_my-div\"]", body)
    @test occursin("ns[\"children\"]", body)
end

@testset "Background callbacks" begin
    app = dash()
    app.layout = html_div() do 
        html_div(html_p(id = "paragraph_id", children = ["Button not clicked"]))
        html_button(id="buttton_id", children = "Run Job!")
    end

    callback!(app, Output("paragraph_id", "children"), Input("button_id", "n_clicks"), background = true) do clicks
        sleep(2)
        return string("Clicked ", clicks, " times")
    end

    handler = make_handler(app)
    request = HTTP.Request("GET", "/_dash-dependencies")
    resp = Dash.HttpHelpers.handle(handler, request)
    deps = JSON3.read(String(resp.body))
    @test deps[1].long
end