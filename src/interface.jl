"""
    interface.jl

Interactive terminal interface: prompts the user for the model inputs, applies
defaults (risk-free rate defaults to 0.05 when nothing is entered), re-prompts
on invalid input, and runs the whole pipeline — summary, path enumeration and
graphs (terminal + PNG).
"""
module Interface

using ..Params: ModelParams, validate, risk_neutral_prob,
                parse_float, parse_optional_float, parse_int
using ..Pricing: StockValuation, value_stock_tree, summarize
using ..Paths: PathSet, enumerate_paths, MAX_ENUM_PATHS
using ..Plotting: plot_price_tree, plot_paths, save_price_tree_png, save_paths_png

export ask_params, run

"""
    ask_params([io_in = stdin, io_out = stdout]) -> ModelParams

Prompt for `S0`, `u`, `d`, `n` and (optionally) `r`, re-prompting until every
answer parses. Leaving the risk-free-rate prompt empty accepts the default
0.05. The final parameters are validated with `validate` — a violated rule
re-runs the whole prompt loop so the user can correct the offending value.
"""
function ask_params(io_in::IO = stdin, io_out::IO = stdout)
    questions = [
        (prompt = "Stock price at time 0 (S0)",
         default = nothing,
         parser = str -> parse_float(str, "S0"),
         validate_fn = v -> v > 0 || "S0 must be strictly positive"),
        (prompt = "Up factor (u)",
         default = nothing,
         parser = str -> parse_float(str, "u"),
         validate_fn = v -> v > 0 || "u must be strictly positive"),
        (prompt = "Down factor (d)",
         default = nothing,
         parser = str -> parse_float(str, "d"),
         validate_fn = v -> v > 0 || "d must be strictly positive"),
        (prompt = "Number of periods (n)",
         default = nothing,
         parser = str -> parse_int(str, "n"),
         validate_fn = v -> v ≥ 1 || "n must be at least 1"),
        (prompt = "Risk-free rate (r)",
         default = 0.05,
         parser = str -> parse_optional_float(str, "r", 0.05),
         validate_fn = v -> v > -1 || "r must be greater than -1"),
    ]

    p = nothing
    while p === nothing
        answers = Any[]
        for q in questions
            suffix = q.default === nothing ? ": " : " [$(q.default)]: "
            v = _ask_one(io_in, io_out, q.prompt * suffix, q.parser, q.validate_fn)
            push!(answers, v)
        end
        try
            p = ModelParams(answers...)
        catch err
            err isa ArgumentError || rethrow()
            println(io_out, "  ⚠  ", sprint(showerror, err))
        end
    end
    return p::ModelParams
end

function _ask_one(io_in::IO, io_out::IO, prompt::AbstractString, parser, validate_fn)
    while true
        print(io_out, prompt)
        s = readline(io_in)
        local v
        try
            v = parser(s)
        catch err
            err isa ArgumentError || rethrow()
            println(io_out, "  ⚠  ", sprint(showerror, err))
            continue
        end
        ok = validate_fn(v)
        ok === true && return v
        println(io_out, "  ⚠  ", ok)
    end
end

"""
    run([io_in = stdin, io_out = stdout]; plot::Symbol = :both) -> StockValuation

Full interactive session: ask for parameters, print the valuation summary,
enumerate every path-dependent price path, draw the price tree and all paths
up to the final period in the terminal, and attempt PNG output.

`plot` selects terminal-only (`:terminal`), PNG-only (`:png`) or both.
"""
function run(io_in::IO = stdin, io_out::IO = stdout; plot::Symbol = :both)
    p = ask_params(io_in, io_out)
    println(io_out)
    println(io_out, "Computing valuation for S0=$(p.S0), u=$(p.u), d=$(p.d), n=$(p.n), r=$(p.r) ...")

    val = value_stock_tree(p)
    summarize(io_out, val, p)
    println(io_out)

    n = p.n
    if n > MAX_ENUM_PATHS
        println(io_out, "n = $n gives 2^$n paths — skipping explicit per-path enumeration (cap n ≤ $MAX_ENUM_PATHS).")
        return val
    end

    ps = enumerate_paths(p; lattice = val.lattice)

    println(io_out, "Enumerated $(length(ps.prices)) path-dependent price paths.")
    println(io_out)

    if plot in (:terminal, :both)
        println(io_out, "Price tree (recombining, steps 0–$n):")
        plot_price_tree(io_out, val.lattice; title = "Price tree — recombining lattice")
        println(io_out)

        println(io_out, "Every path-dependent price path, steps 0–$n:")
        plot_paths(io_out, ps; title = "All price paths — steps 0–$n")
        println(io_out)
    end

    if plot in (:png, :both)
        f1 = save_price_tree_png(val.lattice; title = "Binomial price tree (S0=$(p.S0), u=$(p.u), d=$(p.d), n=$(p.n))")
        f2 = save_paths_png(ps; title = "All $(length(ps.prices)) price paths")
        for f in (f1, f2)
            if f === nothing
                println(io_out, "PNG output skipped (Plots.jl/GR unavailable or backend failed).")
            else
                println(io_out, "PNG written: $f")
            end
        end
    end
    return val
end

end # module Interface
