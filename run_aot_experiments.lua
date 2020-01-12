local benchlib = require "benchmarks.benchlib"

local size = arg[1] or "N"

local tests = {
    {
        name = "Binary Trees",
        dir  = "binarytrees",
        luajit = "jit.lua",
        N = 17, Nsmall = 8,
    },
    {
        name = "Fannkuch",
        dir  = "fannkuchredux",
        luajit = false,
        N = 10, Nsmall = 7,
    },
    {
        name = "Fasta",
        dir  = "fasta",
        luajit  = "jit.lua",
        N = 2000000, Nsmall = 100,
    },
    {
        name = "Mandelbrot",
        dir  = "mandelbrot",
        luajit = "jit.lua",
        N = 3000, Nsmall = 30,
    },
    {
        name = "Nbody",
        dir  = "nbodyTable",
        N = 2000000, Nsmall = 100,
    },
    --{
    --    name = "Nbody",
    --    dir  = "nbody",
    --    luajit = "ffi.lua",
    --    N = 2000000, Nsmall = 100,
    --},
    {
        name = "Spectral Norm",
        dir  = "spectralnorm",
        luajit = false,
        N = 1000, Nsmall = 10,
    },
    {
        name = "Queens",
        dir  = "queen",
        luajit = false,
        N = 13, Nsmall = 4,
    },
    {
        name = "Sieve",
        dir  = "streamSieve",
        luajit = false,
        N = 2000, Nsmall = 10,
    },
}

--local impls = {"lua", "luajit", "luaot", "pallene"}
local impls = {"lua", "luaot", "pallene", "luajit"}
local nrep = 5
local runner = benchlib.modes.chronos

local raw_times = {}
for _, test in ipairs(tests) do
    raw_times[test.dir] = {}
    for _, impl in ipairs(impls) do
        raw_times[test.dir][impl] = {}
        for rep = 1, nrep do

            local luapath
            if impl == "luajit" then
                luapath = "luajit"
            else
                luapath = "./lua/src/lua"
            end

            local benchfile
            if impl == "lua" then
                benchfile = "lua.lua"
            elseif impl == "luajit"  then
                benchfile = test.luajit or "lua.lua"
            elseif impl == "luaot" then
                benchfile = "luaot.c"
            elseif impl == "pallene" then
                benchfile = "pallene.pln"
            else
                error("impossible")
            end

            local bpath = "benchmarks/" .. test.dir .. "/" .. benchfile
            local bargs = { test[size] }
            local cmd = benchlib.prepare_benchmark(luapath, bpath, bargs)
            print("running", test.dir, impl, table.concat(bargs, "\t"), "i="..rep)

            local t = runner.parse(runner.run(cmd))
            print(t.time)

            raw_times[test.dir][impl][rep] = t.time
        end
    end
end

local averages = {}
for _, test in ipairs(tests) do
    averages[test.dir] = {}
    for _, impl in ipairs(impls) do
        local sum = 0.0
        for rep = 1, nrep do
            sum = sum + raw_times[test.dir][impl][rep]
        end
        averages[test.dir][impl] = sum / nrep
    end
end

local ratios = {}
for _, test in ipairs(tests) do
    ratios[test.dir] = {}
    for _, impl in ipairs(impls) do
        ratios[test.dir][impl] =
            averages[test.dir][impl] / averages[test.dir]["lua"]
    end
end



local TAB_HEADER = [[
\begin{tabular}{lrrrr}
\toprule
    \thead{Benchmark} &
    \thead{Lua} &
    \thead{Lua-AOT} &
    \thead{Pallene} &
    \thead{LuaJIT} \\
\midrule]]

local TAB_FOOTER = [[
\bottomrule
\end{tabular}
]]

local function tex_table(name, values)
    local parts = {}
    table.insert(parts, "% " .. name)
    table.insert(parts, TAB_HEADER)

    for _, test in ipairs(tests) do
        local cols = {}
        table.insert(cols, string.format("%-16s", test.name))
        for _, impl in ipairs(impls) do
            local t = values[test.dir][impl]
            local s = string.format("%.2f", t)
            table.insert(cols, string.format("%5s", s))
        end
        table.insert(parts, table.concat(cols, " & ") .. " \\\\")
    end

    table.insert(parts, TAB_FOOTER)

    return table.concat(parts, "\n")
end

local ii = require("inspect")
print("averages =", ii(averages))
print("ratios =", ii(ratios))
print()
print(tex_table("AVERAGES", averages))
print(tex_table("RATIOS", ratios))


