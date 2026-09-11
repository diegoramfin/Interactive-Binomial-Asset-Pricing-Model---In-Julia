#!/usr/bin/env julia
#
# Entry point for the binomial asset pricing model.
#
# Usage:
#   julia --project=. main.jl           # interactive session
#
# The interactive runner prompts for:
#   - Derivative type (european / american / lookback)
#   - Call or put
#   - Strike price (K) — skipped for lookbacks (floating strike)
#   - Capital to deploy into the replicating hedge
#   - Stock price at time 0 (S0)
#   - Up factor (u)
#   - Down factor (d)
#   - Number of periods (n)
#   - Risk-free rate (r) — defaults to 0.05 when left empty
#
# It then prints the stock valuation summary and the option block (fair
# value, per-node delta hedge, per-path replicating wealth), enumerates
# every path-dependent price path, draws terminal graphs of the recombining
# tree and all paths up to the final period, and (when Plots.jl is
# available) writes PNGs to output/.

using BinomialAssetPricing

function main()
    println("══════════════════════════════════════════════════════")
    println("   Binomial Asset Pricing Model  ·  interactive mode")
    println("══════════════════════════════════════════════════════")
    println("Leave the risk-free rate empty to accept the default 0.05.")
    println()

    # plot = :both → terminal graphs + PNG (PNGs skipped automatically when
    # Plots.jl is not installed). Use :terminal or :png to restrict output.
    BinomialAssetPricing.run(plot = :both)

    println()
    println("Done. Thanks for pricing with us!")
    return nothing
end

main()
