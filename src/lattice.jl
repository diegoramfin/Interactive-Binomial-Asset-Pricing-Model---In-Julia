"""
    lattice.jl

Recombining binomial price lattice and backward-induction pricing.

A recombining tree stores node `(k, i)` — time step `k`, `i` down-moves
taken — so it needs only `k + 1` nodes per period instead of `2^k` paths.
The up move multiplies by `u`, the down move by `d`:

    S(k, i) = S0 * u^(k-i) * d^i

`price` runs the risk-neutral backward induction

    V(k, i) = [q·V(k+1, i) + (1-q)·V(k+1, i+1)] / (1 + r)

from terminal values `V(n, ·)` to the root, returning the full value tree.
"""
module Lattice

export build_price_lattice, price, node_up, node_down

"""
    build_price_lattice(S0::Real, u::Real, d::Real, n::Integer) -> Vector{Vector{Float64}}

Build the recombining stock price lattice.

`result[k][i]` is the stock price at time step `k` (0-indexed) after `i - 1`
down moves, for `k = 0…n`. Period 0 holds the single root `[S0]`; period `k`
holds `k + 1` nodes.

# Examples
```julia
julia> build_price_lattice(100, 1.2, 0.8, 2)
3-element Vector{Vector{Float64}}:
 [100.0]
 [120.0, 80.0]
 [144.0, 96.0, 64.0]
```
"""
function build_price_lattice(S0::Real, u::Real, d::Real, n::Integer)
    S0 > 0 || throw(ArgumentError("S0 must be positive."))
    u > 0 || throw(ArgumentError("u must be positive."))
    d > 0 || throw(ArgumentError("d must be positive."))
    n ≥ 1 || throw(ArgumentError("n must be at least 1."))

    lattice = Vector{Vector{Float64}}(undef, n + 1)
    lattice[1] = Float64[S0]                       # Julia is 1-indexed: period 0 → index 1
    @inbounds for k in 2:(n + 1)
        step = k - 1                               # actual time step
        prev = lattice[k - 1]
        row = Vector{Float64}(undef, step + 1)
        row[1] = prev[1] * u                       # one more up than parent's top node
        @inbounds for i in 2:(step + 1)
            row[i] = prev[i - 1] * d               # each remaining node descends from the node above-left
        end
        lattice[k] = row
    end
    return lattice
end

"""
    price(payoff::Function, lattice::Vector{Vector{Float64}}, r::Real, q::Real)
        -> Vector{Vector{Float64}}

Backward-induction value tree for a European claim with terminal payoff
`payoff(S)` (a vector of terminal stock prices in, terminal payoffs out).

`q` is the risk-neutral up probability; the discount factor per period is
`1 / (1 + r)`.
"""
function price(payoff::Function, lattice::Vector{Vector{Float64}},
               r::Real, q::Real)
    n = length(lattice) - 1
    0 < q < 1 || throw(ArgumentError("Risk-neutral probability q must lie in (0, 1), got $q."))
    r > -1 || throw(ArgumentError("Risk-free rate must be > -1, got $r."))

    disc = 1 / (1 + r)
    values = Vector{Vector{Float64}}(undef, n + 1)
    values[n + 1] = Float64[payoff(S) for S in lattice[n + 1]]

    for k in (n - 1):-1:0                           # periods n-1 … 0
        row = Vector{Float64}(undef, k + 1)         # value-tree row for time step k has k+1 nodes
        nxt = values[k + 2]                         # child row (time step k+1)
        for i in 1:(k + 1)
            @inbounds row[i] = disc * (q * nxt[i] + (1 - q) * nxt[i + 1])
        end
        values[k + 1] = row
    end
    return values
end

# Convenience node accessors shared by the path generator and printers.
node_up(lattice::Vector{Vector{Float64}}, k::Int, i::Int) = lattice[k + 2][i]      # up child keeps i
node_down(lattice::Vector{Vector{Float64}}, k::Int, i::Int) = lattice[k + 2][i + 1] # down child shifts i by 1

end # module Lattice
