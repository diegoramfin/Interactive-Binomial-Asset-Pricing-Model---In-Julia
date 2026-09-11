"""
    riskneutral.jl

Payoff functions and risk-neutral (martingale) pricing identities.

Under the risk-neutral measure the discounted stock price is a martingale:

    E^Q[S_{k+1}] = (1 + r) · S_k,   with   E^Q[S_k] = S0 · (1 + r)^k.

`expected_terminal_stock` is the direct `n`-step identity, while
`forward_price` identifies that same expectation with the forward delivery
price `F₀ = S0 · (1 + r)ⁿ` — both are classic textbook sanity checks against
the lattice backward induction in [`Lattice`](@ref).
"""
module RiskNeutral

using ..Params: ModelParams, risk_neutral_prob

export european_call_payoff, european_put_payoff, forward_payoff,
       expected_terminal_stock, forward_price, probability_level_sums

"""Terminal payoff of a European call with strike `K`: `max(S - K, 0)`."""
european_call_payoff(K::Real) = S -> max(S - K, 0.0)

"""Terminal payoff of a European put with strike `K`: `max(K - S, 0)`."""
european_put_payoff(K::Real) = S -> max(K - S, 0.0)

"""Terminal payoff of a long forward struck at `K`: `S - K`."""
forward_payoff(K::Real) = S -> S - K

"""
    expected_terminal_stock(p) -> Float64

Risk-neutral expectation of the terminal stock price after `n` periods:

    E^Q[S_n] = Σⱼ C(n, j) · q^(n-j) · (1-q)^j · S0 · u^(n-j) · d^j

(`j` counts down moves, so up moves number `n - j`.)
"""
function expected_terminal_stock(p::ModelParams)
    q = risk_neutral_prob(p)
    total = 0.0
    for j in 0:p.n                               # j = number of down moves
        w = binomial(p.n, j) * q^(p.n - j) * (1 - q)^j
        total += w * p.S0 * p.u^(p.n - j) * p.d^j
    end
    return total
end

"""
    forward_price(p) -> Float64

Time-0 delivery price of a forward on the stock maturing at period `n`.
Under the risk-neutral measure `E^Q[S_n] = S0 · (1 + r)ⁿ`, i.e. exactly the
cost-of-carry forward price.
"""
forward_price(p::ModelParams) = expected_terminal_stock(p)

"""
    probability_level_sums(p_up::Real, p_down::Real, n::Integer)
        -> Vector{Float64}

Propagate probability mass recursively through the recombining tree: the
root holds mass 1 and every node splits its mass into `p_up` for the up
child and `p_down` for the down child. Returns the total mass of each
level `k = 0…n`.

For a genuine probability measure every level sums to exactly 1 — the
`k = n` entry is `Σ_ω P(ω)` over all `2^n` paths, grouped by terminal node.
Both branch probabilities are taken as arguments (rather than deriving
`1 - p_up` internally) so the check validates the two independently
derived formulas `p̃` and `q̃` instead of being a tautology.
"""
function probability_level_sums(p_up::Real, p_down::Real, n::Integer)
    0 ≤ p_up ≤ 1 || throw(ArgumentError("p_up must lie in [0, 1], got $p_up."))
    0 ≤ p_down ≤ 1 || throw(ArgumentError("p_down must lie in [0, 1], got $p_down."))
    n ≥ 1 || throw(ArgumentError("n must be at least 1 (got $n)."))

    level = [1.0]                              # period 0: all mass at the root
    sums = Float64[1.0]
    for k in 1:n
        nxt = zeros(Float64, k + 1)
        for i in 1:k
            nxt[i]     += p_up * level[i]        # up child keeps index i
            nxt[i + 1] += p_down * level[i]      # down child shifts to i + 1
        end
        push!(sums, sum(nxt))
        level = nxt
    end
    return sums
end

end # module RiskNeutral
