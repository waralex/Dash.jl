struct Wildcard
    type ::Symbol
end

JSON3.StructTypes.StructType(::Type{Wildcard}) = JSON3.RawType()

JSON3.rawbytes(wild::Wildcard) = string("[\"", wild.type, "\"]")

const MATCH = Wildcard(:MATCH)
const ALL = Wildcard(:ALL)
const ALLSMALLER = Wildcard(:ALLSMALLER)

is_wild(a::T) where {T<:Wildcard} = true
is_wild(a) = false

struct TraitInput end
struct TraitOutput end
struct TraitState end

const IdTypes = Union{String,NamedTuple}

struct Dependency{Trait, IdT<:IdTypes}
    id ::IdT
    property ::String
    Dependency{Trait}(id::T, property::String) where {Trait, T} = new{Trait, T}(id, property)
end

dep_id_string(dep::Dependency{Trait, String}) where {Trait} = dep.id
dep_id_string(dep::Dependency{Trait, <:NamedTuple}) where {Trait} = sorted_json(dep.id)

dependency_tuple(dep::Dependency) = (id = dep_id_string(dep), property = dep.property)

const Input = Dependency{TraitInput}
const State = Dependency{TraitState}
const Output = Dependency{TraitOutput}

JSON3.StructTypes.StructType(::Type{<:Dependency}) = JSON3.StructTypes.Struct()

"""
    Base.==(a::Dependency, b::Dependency)

We use "==" to denote two deps that refer to the same prop on
the same component. In the case of wildcard deps, this means
the same prop on *at least one* of the same components.
"""
function Base.:(==)(a::Dependency, b::Dependency)
    (a.property == b.property) && is_id_matches(a, b)
end

function Base.isequal(a::Dependency, b::Dependency)
    return a == b
end

#The regular unique works using Set and will not work correctly, because in our case "equal" dependencies have different hashes
#This implementation is not algorithmically efficient (O(n^2)), but it is quite suitable for checking the uniqueness of outputs
function check_unique(deps::Vector{<:Dependency})
    tmp = Dependency[]
    for dep in deps
        dep in tmp && return false
        push!(tmp, dep)
    end
    return true
end

is_id_matches(a::Dependency{Trait1, String}, b::Dependency{Trait2, String}) where {Trait1, Trait2} = a.id == b.id
is_id_matches(a::Dependency{Trait1, String}, b::Dependency{Trait2, <:NamedTuple}) where {Trait1, Trait2} = false
is_id_matches(a::Dependency{Trait1, <:NamedTuple}, b::Dependency{Trait2, String}) where {Trait1, Trait2} = false
function is_id_matches(a::Dependency{Trait1, <:NamedTuple}, b::Dependency{Trait2, <:NamedTuple}) where {Trait1, Trait2}
    (Set(keys(a.id)) != Set(keys(b.id))) && return false

    for key in keys(a.id)
        a_value = a.id[key]
        b_value = b.id[key]

        (a_value == b_value) && continue

        a_wild = is_wild(a_value)
        b_wild = is_wild(b_value)

        (!a_wild && !b_wild) && return false #Both not wild
        !(a_wild && b_wild) && continue #One wild, one not
        ((a_value == ALL) || (b_value == ALL)) && continue #at least one is ALL
        ((a_value == MATCH) || (b_value == MATCH)) && return false #one is MATCH and one is ALLSMALLER

    end
    return true
end


struct CallbackDeps
    output ::Vector{<:Output}
    input ::Vector{<:Input}
    state ::Vector{<:State}
    multi_out::Bool
    CallbackDeps(output, input, state, multi_out) = new(output, input, state, multi_out)
    CallbackDeps(output::Output, input, state = State[]) = new(output, input, state, false)
    CallbackDeps(output::Vector{<:Output}, input, state = State[]) = new(output, input, state, true)
end

Base.convert(::Type{Vector{<:Output}}, v::Output{<:IdTypes}) = [v]
Base.convert(::Type{Vector{<:Input}}, v::Input{<:IdTypes}) = [v]
Base.convert(::Type{Vector{<:State}}, v::State{<:IdTypes}) = [v]

struct ClientsideFunction
    namespace ::String
    function_name ::String
end

JSON3.StructTypes.StructType(::Type{ClientsideFunction}) = JSON3.StructTypes.Struct()

struct Callback
    func ::Union{Function, ClientsideFunction}
    dependencies ::CallbackDeps
    prevent_initial_call ::Bool
    # TODO: refine Any s when done
    long ::Any
end

is_multi_out(cb::Callback) = cb.dependencies.multi_out == true
get_output(cb::Callback) = cb.dependencies.output
get_output(cb::Callback, i) = cb.dependencies.output[i]
first_output(cb::Callback) = first(cb.dependencies.output)

struct PreventUpdate <: Exception

end


struct NoUpdate
end

no_update() = NoUpdate()

const ExternalSrcType = Union{String, Dict{String, String}}
