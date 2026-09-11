"""
    paths.jl

Explicit enumeration of every path-dependent price path in the binomial tree.

Where the recombining lattice ([`Lattice`](@ref)) merges nodes that share the
same number of down moves, this module expands the tree into all `2^n`
distinct up/down sequences (each drawn separately in the graph, even if their
final prices coincide). Path `j` (0-indexed) corresponds to the binary
expansion of `j` with `n` digits: bit 0 = up, bit 1 = down.

`n = 10` already gives 1024 paths, so the interactive runner warns and asks
before materialising trees above `MAX_ENUM_PATHS` periods.
"""
module Paths

using ..Params: risk_neutral_prob
import ..Lattice

export PathSet, enumerate_paths, MAX_ENUM_PATHS

"""Sanity cap before path enumeration explodes (`2^n` paths)."""
const MAX_ENUM_PATHS = 20

"""
    PathSet

Explicit path-dependent view of a binomial tree.

# Fields
- `moves::Vector{Vector{Int}}`: one row per path; `1` = up, `0` = down per step.
- `prices::Vector{Vector{Float64}}`: per-path price series including `S0` at index 1.
- `probs::Vector{Float64}`: real-world probability of each path (`p^ups * (1-p)^downs`).

All three vectors are aligned by path index.
"""
struct PathSet
    moves::Vector{Vector{Int}}
    prices::Vector{Vector{Float64}}
    probs::Vector{Float64}
end

"""
    enumerate_paths(p, p_up::Real = risk_neutral_prob(p); lattice = nothing) -> PathSet

Enumerate all `2^n` price paths of the tree described by `p`.

`p_up` is the probability of an up move per step — by default the risk-neutral
probability [`risk_neutral_prob`](@ref), but pass any scenario probability you
want to visualise (e.g. a subjective/physical view).

The keyword `lattice` accepts a prebuilt price lattice (from
`Lattice.build_price_lattice`) so the two views never disagree.

# Examples
```julia
julia> ps = enumerate_paths(ModelParams(100.0, 1.2, 0.8, 2); lattice = lat)
julia> ps.prices[1]          # up, up
[100.0, 120.0, 144.0]
julia> ps.probs[4]           # down, down  (p = 0.625 ⇒ 0.375²)
0.140625
```
"""
function enumerate_paths(p, p_up::Real = risk_neutral_prob(p); lattice = nothing)
    S0, u, d, n, r = p.S0, p.u, p.d, p.n, p.r
    0 < p_up < 1 || throw(ArgumentError("p_up must lie in (0, 1), got $p_up."))
    n ≤ MAX_ENUM_PATHS ||
        throw(ArgumentError("Refusing to enumerate 2^$n paths; cap is n ≤ $MAX_ENUM_PATHS."))

    lat = lattice === nothing ? Lattice.build_price_lattice(S0, u, d, n) : lattice
    moves = Vector{Vector{Int}}(undef, 2^n)
    prices = Vector{Vector{Float64}}(undef, 2^n)
    probs = Vector{Float64}(undef, 2^n)

    for j in 0:(2^n - 1)
        path_moves = Vector{Int}(undef, n)
        path_prices = Vector{Float64}(undef, n + 1)
        path_prices[1] = S0
        node = 1                          # index i inside recombining row: i-1 = downs so far
        p_up_cur = 1.0
        mask = j
        for k in 1:n
            if iseven(mask)               # bit 0 → up
                path_moves[k] = 1
                node = node               # up keeps the node index
                p_up_cur *= p_up
            else                          # bit 1 → down
                path_moves[k] = 0
                node += 1                 # down shifts one slot right
                p_up_cur *= (1 - p_up)
            end
            path_prices[k + 1] = lat[k + 1][node]
            mask >>= 1
        end
        idx = j + 1
        moves[idx] = path_moves
        prices[idx] = path_prices
        probs[idx] = p_up_cur
    end
    return PathSet(moves, prices, probs)
end

end # module Paths
