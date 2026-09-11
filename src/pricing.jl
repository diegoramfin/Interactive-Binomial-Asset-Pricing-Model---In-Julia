"""
    pricing.jl

High-level valuation facade tying the other modules together.

`value_stock_tree` produces everything the reports and graphs need from a
single call: the recombining price lattice, the risk-neutral backward-induction
value tree, the risk-neutral probability, and the time-0 fair values.
"""
module Pricing

using ..Params: ModelParams, risk_neutral_prob, risk_neutral_down_prob, validate
using ..Lattice: build_price_lattice, price
using ..RiskNeutral: expected_terminal_stock, forward_price, probability_level_sums

export StockValuation, value_stock_tree, summarize

"""
    StockValuation

Bundle of everything computed for one set of `ModelParams`.

# Fields
- `lattice::Vector{Vector{Float64}}`: recombining stock price lattice (`lattice[k+1][i]` = price at step `k` after `i-1` downs).
- `values::Vector{Vector{Float64}}`: risk-neutral value tree for holding the stock (`values[1][1]` is the time-0 fair value).
- `q::Float64`: risk-neutral probability of an up move.
- `S0_fair::Float64`: time-0 fair value of the stock (equals the discounted terminal expectation).
- `forward0::Float64`: time-0 price of a forward delivered at period `n`.
"""
struct StockValuation
    lattice::Vector{Vector{Float64}}
    values::Vector{Vector{Float64}}
    q::Float64
    S0_fair::Float64
    forward0::Float64
end

"""
    value_stock_tree(p::ModelParams) -> StockValuation

Validate `p`, build the price lattice, and run risk-neutral backward induction
on the "hold the stock" claim with terminal payoff `S_n`.

Because the discounted stock is a martingale under `Q`, the value tree equals
the price lattice itself up to discounting — a useful sanity check:
`values[1][1] ≈ E^Q[S_n] / (1 + r)^n ≈ S0`.
"""
function value_stock_tree(p::ModelParams)
    validate(p)
    lattice = build_price_lattice(p.S0, p.u, p.d, p.n)
    q = risk_neutral_prob(p)
    values = price(identity, lattice, p.r, q)
    return StockValuation(lattice, values, q, values[1][1], forward_price(p))
end

"""
    summarize(io::IO, v::StockValuation, p::ModelParams)

Print a human-readable valuation report to `io`.
"""
function summarize(io::IO, v::StockValuation, p::ModelParams)
    n, r = p.n, p.r
    q_down = risk_neutral_down_prob(p)
    level_sums = probability_level_sums(v.q, q_down, n)
    max_dev = maximum(s -> abs(s - 1), level_sums)
    ok = all(s -> isapprox(s, 1.0; atol = 1e-10), level_sums)

    println(io, "─"^58)
    println(io, " Binomial model: S0=$(p.S0), u=$(p.u), d=$(p.d), n=$n, r=$r")
    println(io, "─"^58)
    println(io, " Risk-neutral up prob p̃             : $(round(v.q, digits=6))")
    println(io, " Risk-neutral down prob q̃           : $(round(q_down, digits=6))")
    println(io, " p̃ + q̃  (must equal 1)              : $(round(v.q + q_down, digits=6))")
    println(io, " Recursive level-mass check         : $(ok ? "PASS" : "FAIL")  (levels 0–$n, max |Σ−1| = $(round(max_dev, sigdigits=3)))")
    println(io, " E^Q[S_n]  (terminal expectation)   : $(round(expected_terminal_stock(p), digits=6))")
    println(io, " S0 · (1+r)^n  (martingale check)   : $(round(p.S0 * (1 + r)^n, digits=6))")
    println(io, " Forward price (delivery at n)      : $(round(v.forward0, digits=6))")
    println(io, " Fair value of stock at t=0         : $(round(v.S0_fair, digits=6))")
    println(io, "─"^58)
end

summarize(v::StockValuation, p::ModelParams) = summarize(stdout, v, p)

end # module Pricing
