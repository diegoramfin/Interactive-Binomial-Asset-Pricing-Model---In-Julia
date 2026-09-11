"""
    BinomialAssetPricing

Julia implementation of the binomial asset pricing model (Cox–Ross–Rubinstein
style): a recombining price lattice, risk-neutral backward induction, explicit
enumeration of every path-dependent price path, and terminal/PNG graphs.

## Modules

- `Params`       — validated model parameters + strict CLI parsing helpers.
- `Lattice`      — recombining stock price lattice and backward induction.
- `RiskNeutral`  — payoff functions and martingale sanity identities.
- `Paths`        — explicit enumeration of all `2^n` price paths.
- `Options`      — European/American/lookback contracts, delta hedging and
  the replicating-portfolio check `X_n(ω) = V_n(ω)`.
- `Plotting`     — Unicode terminal plots with ASCII fallback + PNG output.
- `Pricing`      — high-level valuation facade (`value_stock_tree`).
- `Interface`    — interactive prompts with defaults and the `run` pipeline.
"""
module BinomialAssetPricing

include("params.jl")
include("riskneutral.jl")
include("lattice.jl")
include("paths.jl")
include("options.jl")
include("plotting.jl")
include("pricing.jl")
include("interface.jl")

using .Params: ModelParams, validate, risk_neutral_prob, risk_neutral_down_prob,
             parse_float, parse_int, parse_choice
using .Lattice: build_price_lattice
using .Pricing: StockValuation, value_stock_tree, summarize
using .Paths: PathSet, enumerate_paths
using .Options: OptionSpec, OptionValuation, value_option, summarize_option,
                path_payoff
using .Plotting: plot_price_tree, plot_paths, save_price_tree_png, save_paths_png
using .Interface: ask_params, ask_contract, run

# Rexport the core surface so `using BinomialAssetPricing` is enough.
export ModelParams, validate, risk_neutral_prob, risk_neutral_down_prob,
       parse_float, parse_int, parse_choice,
       build_price_lattice, StockValuation, value_stock_tree, summarize,
       PathSet, enumerate_paths,
       OptionSpec, OptionValuation, value_option, summarize_option, path_payoff,
       plot_price_tree, plot_paths, save_price_tree_png, save_paths_png,
       ask_params, ask_contract, run

end # module
