# BinomialAssetPricing.jl

The binomial asset pricing model (Cox–Ross–Rubinstein style), built as a set
of isolated Julia modules and driven by a small interactive entry point.

> 🚀 **New here?** See [QUICKSTART.md](QUICKSTART.md) to get running in five minutes.

You pick a contract — **european / american / lookback**, then **call** or
**put**, plus a strike **K** for vanilla options — and enter **S₀** (stock
price at time 0), **u** (up factor), **d** (down factor) and the number of
periods **n**. The one-period risk-free rate **r** defaults to **0.05** when
you leave the prompt empty. The program validates the no-arbitrage condition
`d < 1 + r < u`, prices the stock by risk-neutral backward induction on a
recombining lattice, prices the option (lattice for european/american, the
full `2^n` path tree for the floating-strike lookback), and computes the
delta hedge `Δ_n(ω)` — rolling the replicating portfolio `X` forward along
every path to show `X_k = V_k` regardless of the outcome. Finally it
enumerates **every path-dependent price path** (`2^n` of them) and graphs
each path up to the final period — in the terminal and, when available, as
PNG images.

## Quick start

```bash
julia --project=. -e 'using Pkg; Pkg.instantiate()'   # once
julia --project=. main.jl
```

Example session (with a pre-planted input file):

```text
Derivative type (european/american/lookback): european
Call or put (call/put): call
Strike price (K): 105
Capital to deploy for the hedge: 1000
Stock price at time 0 (S0): 100
Up factor (u): 1.2
Down factor (d): 0.8
Number of periods (n): 3
Risk-free rate (r) [0.05]:                    ← just press Enter
```

Output:

- a valuation summary (risk-neutral probabilities `p̃`/`q̃`, martingale
  checks, forward price);
- an option block: fair value, `E^Q[payoff]` (per contract and scaled to
  the deployed capital), the per-node delta hedge, and a per-path wealth
  table showing the replication matching `V_k` step by step;
- the recombining price tree drawn as terminal plot;
- a plot of all 2^n price paths through the final period;
- PNG versions written to `output/` when Plots.jl is installed.

## Project layout

```text
main.jl                 # root-level interactive pipeline entry point
src/
├── BinomialAssetPricing.jl   # top-level module, includes & re-exports
├── params.jl                 # ModelParams, validation, CLI parsing (r defaults to 0.05)
├── lattice.jl                # recombining price lattice + backward induction
├── riskneutral.jl            # payoffs & martingale/forward identities
├── paths.jl                  # explicit enumeration of all 2^n price paths
├── options.jl                # option specs, american/lookback pricing, delta hedge, replication check
├── plotting.jl               # UnicodePlots terminal graphs, ASCII fallback, Plots.jl PNGs
├── pricing.jl                # valuation facade (value_stock_tree, summarize)
└── interface.jl              # interactive prompts + run() orchestration
test/runtests.jl        # unit & integration tests
output/                 # generated PNGs (gitignored)
```

Dependencies flow inward: `main.jl → Interface → {Params, Pricing, Paths,
Plotting} → Lattice / RiskNeutral`. Each module is independently testable.

## The model

One period: the stock moves from `S` to `uS` (up) or `dS` (down); cash grows
at `1 + r`. No arbitrage forces `d < 1 + r < u`, which makes the risk-neutral
up-probability

```text
q = ((1 + r) - d) / (u - d)          ∈ (0, 1)
```

the unique probability under which the discounted stock is a martingale.
Any European claim with terminal payoff `g(S_n)` is then worth

```text
V₀ = E^Q[g(S_n)] / (1 + r)^n
```

computed on the lattice by backward induction `V(k,i) = [p̃·V(k+1,i) +
q̃·V(k+1,i+1)] / (1+r)`. For the stock itself (`g = identity`) this returns
`S₀` — the built-in sanity check. `RiskNeutral.expected_terminal_stock`
verifies `E^Q[S_n] = S₀(1+r)^n` directly via the binomial sum, and
`forward_price` identifies the period-`n` forward as `S₀(1+r)^n`.

## Options, delta hedging and replication

`Options.value_option` prices a contract and its replicating hedge:

- **european** call/put — backward induction of `(S_n−K)⁺` / `(K−S_n)⁺`.
- **american** call/put — same, but `V = max(exercise, continuation)` at
  every node; nodes where early exercise is optimal are flagged and the
  early-exercise premium over the european twin is reported.
- **lookback** call/put — floating-strike path-dependent claim
  (`S_T − min S` / `max S − S_T`), priced on the full `2^n` path tree,
  so `n ≤ 20`.

The delta hedge at each node is `Δ = (V(H) − V(T)) / (S(H) − S(T))`, and
the replicating wealth `X_{k+1} = Δ_k S_{k+1} + (1+r)(X_k − Δ_k S_k)` is
rolled forward from `X_0 = V_0` along all `2^n` paths — the report checks
`X_k(ω) = V_k(ω)` at every step (up to the exercise time for american
contracts). The capital you enter sizes the position as
`contracts = capital / V₀`.

## Graphing

- **Terminal plots** (`UnicodePlots`, bundled): price tree and per-path lines.
- **ASCII fallback**: if UnicodePlots cannot load, a compact box-drawing/ASCII
  rendering is printed instead — the run never fails for lack of a backend.
- **PNGs** (`Plots.jl` + GR, bundled): saved to `output/price_tree.png` and
  `output/price_paths.png`; skipped with a notice if the GR backend is
  unavailable (e.g. missing system libraries).

## Library use

```julia
using BinomialAssetPricing

p  = ModelParams(100.0, 1.2, 0.8, 5)        # r defaults to 0.05
v  = value_stock_tree(p)                    # lattice, value tree, q, fair values
ps = enumerate_paths(p)                     # all 2^5 path-dependent paths
ps.prices[1]                                # [100, 120, 144, 172.8, 207.36, 248.83]

# European call via backward induction:
using BinomialAssetPricing.RiskNeutral: european_call_payoff
using BinomialAssetPricing.Lattice: price
tree = price(european_call_payoff(100), v.lattice, p.r, v.q)
tree[1][1]                                  # time-0 call value

# Full contract facade — pricing + delta hedge + replication check:
ov = value_option(p, OptionSpec(:american, :put, 105.0), 1000.0)
ov.V0                                       # fair value
ov.exercise_premium                         # vs the european twin
ov.deltas[1][1]                             # Δ0 in shares per contract
ov.contracts                                # contracts the capital replicates
```

## Tests

```bash
julia --project=. -e 'using Pkg; Pkg.test()'
```
