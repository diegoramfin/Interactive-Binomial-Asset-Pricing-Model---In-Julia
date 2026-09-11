using Test
using BinomialAssetPricing
using BinomialAssetPricing.Params
using BinomialAssetPricing.Lattice
using BinomialAssetPricing.RiskNeutral
using BinomialAssetPricing.Paths
using BinomialAssetPricing.Pricing

@testset "Params" begin
    p = ModelParams(100.0, 1.2, 0.8, 3)                       # r defaults to 0.05
    @test p.r == 0.05
    @test p.n == 3
    @test risk_neutral_prob(p) ≈ ((1.05 - 0.8) / (1.2 - 0.8)) # = 0.625
    @test risk_neutral_down_prob(p) ≈ ((1.2 - 1.05) / (1.2 - 0.8)) # = 0.375
    @test risk_neutral_prob(p) + risk_neutral_down_prob(p) ≈ 1.0  # p̃ + q̃ = 1
    @test validate(p) === nothing

    # Out-of-range / malformed inputs are rejected.
    @test_throws ArgumentError validate(ModelParams(0.0, 1.2, 0.8, 3))
    @test_throws ArgumentError validate(ModelParams(100.0, 0.8, 1.2, 3))   # u ≤ d
    @test_throws ArgumentError validate(ModelParams(100.0, 1.1, 0.95, 2, 0.10)) # d < 1+r < u fails
    @test_throws ArgumentError validate(ModelParams(100.0, 1.2, 0.8, 0))
    @test_throws ArgumentError validate(ModelParams(100.0, NaN, 0.8, 3))

    # Strict parsing helpers.
    @test parse_float(" 100.5 ", "S0") == 100.5
    @test parse_int(" 5 ", "n") == 5
    @test parse_optional_float("", "r", 0.05) == 0.05        # empty → default
    @test parse_optional_float(" 0.03 ", "r", 0.05) == 0.03
    @test_throws ArgumentError parse_float("", "S0")
    @test_throws ArgumentError parse_float("abc", "S0")
    @test_throws ArgumentError parse_float("NaN", "S0")
    @test_throws ArgumentError parse_int("3.5", "n")
    @test_throws ArgumentError parse_int("0", "n")
end

@testset "Lattice" begin
    lat = build_price_lattice(100.0, 1.2, 0.8, 2)
    @test lat == [[100.0], [120.0, 80.0], [144.0, 96.0, 64.0]]
    @test length(build_price_lattice(100, 1.2, 0.8, 5)) == 6
    @test_throws ArgumentError build_price_lattice(-1.0, 1.2, 0.8, 2)

    # Risk-neutral backward induction on the stock itself reproduces S0:
    # the discounted stock is a Q-martingale.
    p = ModelParams(100.0, 1.2, 0.8, 5)
    q = risk_neutral_prob(p)
    vals = price(identity, build_price_lattice(p.S0, p.u, p.d, p.n), p.r, q)
    @test vals[1][1] ≈ 100.0 atol = 1e-8

    # European put via backward induction equals the direct expectation
    # Σ C(n,j) q^(n-j) (1-q)^j max(K - S0 u^(n-j) d^j, 0), discounted once.
    K = 105.0
    pv = price(european_put_payoff(K), build_price_lattice(100, 1.2, 0.8, 3), 0.05, 0.625)
    direct = sum(binomial(3, j) * 0.625^(3 - j) * 0.375^j *
                 max(K - 100 * 1.2^(3 - j) * 0.8^j, 0.0) for j in 0:3) / 1.05^3
    @test pv[1][1] ≈ direct atol = 1e-10

    @test_throws ArgumentError price(identity, lat, 0.05, 1.5)
end

@testset "RiskNeutral identities" begin
    for (S0, u, d, n, r) in [(100.0, 1.2, 0.8, 4, 0.05), (50.0, 1.1, 0.9, 7, 0.02)]
        p = ModelParams(S0, u, d, n, r)
        @test expected_terminal_stock(p) ≈ S0 * (1 + r)^n   # Q-martingale
        @test forward_price(p) ≈ S0 * (1 + r)^n             # cost of carry
    end

    # Recursive mass propagation: each node splits its mass p̃/q̃, so a valid
    # measure keeps every tree level — and the 2^n terminal paths — at sum 1.
    for n in (1, 2, 3, 10)
        sums = probability_level_sums(0.625, n)
        @test length(sums) == n + 1
        @test all(s -> s ≈ 1.0, sums)
    end
    @test_throws ArgumentError probability_level_sums(1.5, 3)
    @test_throws ArgumentError probability_level_sums(0.5, 0)
end

@testset "Paths" begin
    p = ModelParams(100.0, 1.2, 0.8, 2)
    ps = enumerate_paths(p)
    @test length(ps.prices) == 4
    @test ps.prices[1] == [100.0, 120.0, 144.0]             # up, up
    @test ps.prices[4] == [100.0, 80.0, 64.0]               # down, down
    @test sum(ps.probs) ≈ 1.0 atol = 1e-12
    @test all(ps.prices[i][1] == 100.0 for i in 1:4)

    # Every explicit path must agree with the recombining lattice: a path's
    # node at step k is 1 + (number of down moves taken in the first k steps).
    lat = build_price_lattice(p.S0, p.u, p.d, p.n)
    for (moves, prices) in zip(ps.moves, ps.prices)
        node = 1
        @test prices[1] == lat[1][1]
        for (k, mv) in enumerate(moves)
            node += mv == 0 ? 1 : 0
            @test prices[k + 1] == lat[k + 1][node]
        end
    end

    @test_throws ArgumentError enumerate_paths(ModelParams(100, 1.2, 0.8, 25))
end

@testset "Pricing facade" begin
    p = ModelParams(100.0, 1.2, 0.8, 4)
    v = value_stock_tree(p)
    @test v.q ≈ 0.625
    @test v.S0_fair ≈ 100.0 atol = 1e-8
    @test v.forward0 ≈ 100 * 1.05^4
    @test length(v.lattice) == 5 && length(v.values) == 5
    @test all(length(v.lattice[k]) == k for k in 1:5)
    io = IOBuffer()
    summarize(io, v, p)
    s = String(take!(io))
    @test occursin("0.625", s)                              # p̃ (up prob)
    @test occursin("0.375", s)                              # q̃ (down prob)
    @test occursin("PASS", s)                               # level-mass check
end

@testset "Interface" begin
    using BinomialAssetPricing.Interface
    using BinomialAssetPricing.Plotting

    # Empty risk-free rate → default 0.05; bad values re-prompt.
    input = IOBuffer("100\n1.2\n0.8\n3\n\n")                  # r left empty
    out = IOBuffer()
    v = Interface.run(input, out; plot = :none)
    s = String(take!(out))
    @test v.S0_fair ≈ 100.0 atol = 1e-8
    @test occursin("Enumerated 8", s)                         # 2^3 paths
    @test occursin("[0.05]", s)                               # default shown in prompt

    # Invalid entries trigger re-prompts, then succeed.
    input2 = IOBuffer("-5\n100\n1.2\n0.8\n2\n0.03\n")
    out2 = IOBuffer()
    v2 = Interface.run(input2, out2; plot = :none)
    @test v2.q ≈ (1.03 - 0.8) / 0.4
    @test occursin("strictly positive", String(take!(out2)))

    # Terminal plotting works headlessly (fallback or UnicodePlots), PNG skipped.
    io = IOBuffer()
    plot_price_tree(io, build_price_lattice(100, 1.2, 0.8, 3))
    @test !isempty(String(take!(io)))
    io2 = IOBuffer()
    plot_paths(io2, enumerate_paths(ModelParams(100, 1.2, 0.8, 3)))
    @test !isempty(String(take!(io2)))

    # PNG functions degrade to `nothing` when Plots.jl is not loadable.
    if !Plotting._plots
        @test save_price_tree_png(build_price_lattice(100, 1.2, 0.8, 2)) === nothing
        @test save_paths_png(enumerate_paths(ModelParams(100, 1.2, 0.8, 2))) === nothing
    end
end
