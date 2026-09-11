# Quickstart

Get the binomial asset pricing model running in under five minutes.

## 1. Prerequisites

- **Julia ≥ 1.10** — check with `julia --version`, or install from
  [julialang.org](https://julialang.org/downloads/).

## 2. Install dependencies (once)

From the project root:

```bash
julia --project=. -e 'using Pkg; Pkg.instantiate(); Pkg.precompile()'
```

This pulls in `Plots`, `UnicodePlots` and `Printf` (first run takes a few
minutes; after that everything is cached).

## 3. Run it

```bash
julia --project=. main.jl
```

You will be prompted for:

| Prompt | Meaning | Rule |
|---|---|---|
| `Stock price at time 0 (S0)` | initial stock price | > 0 |
| `Up factor (u)` | multiplier on an up move | > 0 and > d |
| `Down factor (d)` | multiplier on a down move | > 0 and < u |
| `Number of periods (n)` | depth of the tree | ≥ 1 (≤ 20 for path plots) |
| `Risk-free rate (r) [0.05]` | one-period rate, e.g. `0.05` = 5% | > -1 — **press Enter to accept the 0.05 default** |

Invalid input is re-prompted with a reason; the no-arbitrage condition
`d < 1 + r < u` is enforced before any pricing happens.

## 4. Example session

Inputs `100`, `1.2`, `0.8`, `3`, and Enter for the rate produce:

```text
──────────────────────────────────────────────────────────
 Binomial model: S0=100.0, u=1.2, d=0.8, n=3, r=0.05
──────────────────────────────────────────────────────────
 Risk-neutral up probability q      : 0.625
 E^Q[S_n]  (terminal expectation)   : 115.7625
 S0 · (1+r)^n  (martingale check)   : 115.7625
 Forward price (delivery at n)      : 115.7625
 Fair value of stock at t=0         : 100.0
──────────────────────────────────────────────────────────

Enumerated 8 path-dependent price paths.
```

followed by two terminal plots (recombining price tree, and every individual
path through the final period), then PNG output:

```text
PNG written: output/price_tree.png
PNG written: output/price_paths.png
```

## 5. Outputs

- **Terminal plots** — Unicode renderings of the tree and all `2^n` paths;
  degrade to ASCII art if `UnicodePlots` cannot load.
- **`output/price_tree.png`** — the recombining lattice, one line per generation.
- **`output/price_paths.png`** — every path-dependent price path, colored.
- PNGs are skipped with a notice (not an error) if the GR backend is unavailable.

Note: explicit per-path enumeration is capped at `n ≤ 20` (2²⁰ = 1M paths).
Larger trees still price correctly on the lattice; only the per-path plots are skipped.

## 6. Use as a library

```julia
julia> using BinomialAssetPricing

julia> p  = ModelParams(100.0, 1.2, 0.8, 5)   # r defaults to 0.05

julia> v  = value_stock_tree(p)               # lattice, value tree, q, fair values

julia> ps = enumerate_paths(p)                # all 2^5 path-dependent paths
julia> ps.prices[1]                           # the all-ups path

# European call via backward induction:
julia> using BinomialAssetPricing.RiskNeutral: european_call_payoff
julia> using BinomialAssetPricing.Lattice: price
julia> tree = price(european_call_payoff(100), v.lattice, p.r, v.q)
julia> tree[1][1]                             # time-0 call value
```

## 7. Run the tests

```bash
julia --project=. -e 'using Pkg; Pkg.test()'
```

See `README.md` for the module layout and the math behind the model.
