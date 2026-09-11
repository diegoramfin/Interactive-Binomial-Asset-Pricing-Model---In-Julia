"""
    params.jl

Model parameters and validation for the binomial asset pricing model.

The user supplies four values: the initial stock price `S₀`, the up factor
`u`, the down factor `d`, and the number of discrete periods `n`. The
one-period risk-free rate `r` is optional and defaults to `0.05` when the
user enters nothing.
"""
module Params

export ModelParams, risk_neutral_prob, risk_neutral_down_prob, validate,
       parse_float, parse_int, parse_optional_float, parse_choice

"""
    ModelParams

Immutable container for binomial model inputs.

# Fields
- `S0::Float64`: stock price at time 0 (must be > 0)
- `u::Float64`:  up factor per period (must be > 0)
- `d::Float64`:  down factor per period (must be > 0)
- `n::Int`:      number of periods (must be ≥ 1)
- `r::Float64`:  one-period risk-free rate, e.g. `0.05` for 5% (must be > -1)

# Validation rules
1. All numeric fields must be finite (`NaN`/`Inf` rejected).
2. `u > d` — otherwise the tree collapses and "up"/"down" lose meaning.
3. No arbitrage: `d < 1 + r < u`, which keeps the risk-neutral probability
   strictly inside `(0, 1)` and rules out free lunches.

# Examples
```julia
p = ModelParams(100.0, 1.2, 0.8, 3)         # r defaults to 0.05
p = ModelParams(100.0, 1.2, 0.8, 3, 0.03)   # explicit risk-free rate
```
"""
struct ModelParams
    S0::Float64
    u::Float64
    d::Float64
    n::Int
    r::Float64
end

# Keywords constructor: positional calls keep order S0, u, d, n, r.
ModelParams(S0::Real, u::Real, d::Real, n::Integer, r::Real = 0.05) =
    ModelParams(Float64(S0), Float64(u), Float64(d), Int(n), Float64(r))

"""
    validate(p::ModelParams)

Throw an `ArgumentError` describing the first violated rule, or return
`nothing` when the parameters describe a sane, arbitrage-free market.
"""
function validate(p::ModelParams)
    all(isfinite, (p.S0, p.u, p.d, p.r)) || throw(ArgumentError("All inputs must be finite numbers."))
    p.S0 > 0 || throw(ArgumentError("Stock price S0 must be strictly positive (got $(p.S0))."))
    p.u > 0 || throw(ArgumentError("Up factor u must be strictly positive (got $(p.u))."))
    p.d > 0 || throw(ArgumentError("Down factor d must be strictly positive (got $(p.d))."))
    p.u > p.d || throw(ArgumentError("Up factor must exceed down factor (u=$(p.u) ≤ d=$(p.d))."))
    p.n ≥ 1 || throw(ArgumentError("Number of periods n must be at least 1 (got $(p.n))."))
    p.r > -1 || throw(ArgumentError("Risk-free rate must be greater than -100% (got $(p.r))."))
    p.d < 1 + p.r < p.u ||
        throw(ArgumentError("No-arbitrage violated: need d < 1 + r < u, got d=$(p.d), 1+r=$(1 + p.r), u=$(p.u)."))
    return nothing
end

"""
    risk_neutral_prob(p::ModelParams) -> Float64

Risk-neutral probability of an up move, `q = ((1 + r) - d) / (u - d)`.

Valid because `validate` guarantees `d < 1 + r < u`, hence `0 < q < 1`.
"""
risk_neutral_prob(p::ModelParams) = ((1 + p.r) - p.d) / (p.u - p.d)

"""
    risk_neutral_down_prob(p::ModelParams) -> Float64

Risk-neutral probability of a down move, `q̃ = (u - (1 + r)) / (u - d)`.

Computed from its own formula rather than as `1 - p̃` so that the identity
`p̃ + q̃ = 1` is a genuine check on the two derivations, not a tautology.
"""
risk_neutral_down_prob(p::ModelParams) = (p.u - (1 + p.r)) / (p.u - p.d)

# ------------------------------------------------------------------
# Strict CLI parsing helpers
# ------------------------------------------------------------------

"""
    parse_float(str::AbstractString, name::AbstractString) -> Float64

Parse a strictly finite, non-empty float; `ArgumentError` on anything else.
An empty string (user pressed Enter on an optional prompt) returns `nothing`
via [`parse_optional_float`](@ref); here emptiness is an error.
"""
function parse_float(str::AbstractString, name::AbstractString)
    s = strip(str)
    isempty(s) && throw(ArgumentError("$name must not be empty."))
    v = tryparse(Float64, s)
    v === nothing && throw(ArgumentError("'$s' is not a valid number for $name."))
    isfinite(v) || throw(ArgumentError("$name must be a finite number (got $v)."))
    return v
end

"""
    parse_optional_float(str::AbstractString, name::AbstractString, default) -> Float64

Like [`parse_float`](@ref) but an empty (or whitespace-only) string yields
`default` — used for the risk-free rate prompt.
"""
function parse_optional_float(str::AbstractString, name::AbstractString, default::Float64)
    s = strip(str)
    isempty(s) && return default
    return parse_float(s, name)
end

"""
    parse_int(str::AbstractString, name::AbstractString) -> Int

Parse a strictly positive integer; `ArgumentError` on anything else.
"""
function parse_int(str::AbstractString, name::AbstractString)
    s = strip(str)
    isempty(s) && throw(ArgumentError("$name must not be empty."))
    v = tryparse(Int, s)
    v === nothing && throw(ArgumentError("'$s' is not a valid integer for $name."))
    v ≥ 1 || throw(ArgumentError("$name must be at least 1 (got $v)."))
    return v
end

"""
    parse_choice(str::AbstractString, name::AbstractString, allowed) -> Symbol

Parse a case-insensitive menu pick; `str` must be one of the strings in
`allowed` after trimming/lowercasing, else `ArgumentError`. Returns the
choice as a `Symbol` — used for the derivative-type and call/put prompts.
"""
function parse_choice(str::AbstractString, name::AbstractString, allowed)
    s = lowercase(strip(str))
    s in allowed ||
        throw(ArgumentError("$name must be one of: $(join(allowed, ", ")) (got '$s')."))
    return Symbol(s)
end

end # module Params
