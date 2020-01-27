local benchlib = require "benchmarks.benchlib"

local size = arg[1] or "N"

local tests = {
    --{
    --    name = "Binary Trees",
    --    dir  = "binarytrees",
    --    luajit = "jit.lua",
    --    N = 17, Nsmall = 8,
    --},
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
        name = "Stream Sieve",
        dir  = "streamSieve",
        luajit = false,
        N = 2000, Nsmall = 10,
    },
}

local impls = {"lua", "luaot", "luajit", "pallene"}
local nrep = 10
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

local maximums = {}
for _, test in ipairs(tests) do
    maximums[test.dir] = {}
    for _, impl in ipairs(impls) do
        local times = raw_times[test.dir][impl]
        maximums[test.dir][impl] = math.max(table.unpack(times))
    end
end

local minimums = {}
for _, test in ipairs(tests) do
    minimums[test.dir] = {}
    for _, impl in ipairs(impls) do
        local times = raw_times[test.dir][impl]
        minimums[test.dir][impl] = math.min(table.unpack(times))
    end
end

local with_errors = {}
for _, test in ipairs(tests) do
    with_errors[test.dir] = {}
    for _, impl in ipairs(impls) do
        local a = averages[test.dir][impl]
        local hi = maximums[test.dir][impl]
        local lo = minimums[test.dir][impl]
        local delta = math.max(hi-a, a-lo)
        with_errors[test.dir][impl] =
            string.format("$%.2f \\pm %.2f$", a, delta)
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

local impl_names = {
    ["lua"]   = "Lua",
    ["luaot"] = "Lua-AOT",
    ["luajit"] = "LuaJIT",
    ["pallene"] = "Pallene",
}

local function totexrow(elems)
    return "    " .. table.concat(elems, " & ") .. " \\\\"
end

local function totexstring(v)
    if     type(v) == "string" then
        return v
    elseif type(v) == "number" then
        return string.format("%.2f", v)
    else
        error("type " .. type(v) .. " not allowed")
    end
end

local function tex_table(name, columns, values)
    local parts = {}
    table.insert(parts, "% " .. name)
    table.insert(parts, "\\begin{tabular}{lrrrr}")
    table.insert(parts, "\\toprule")

    local header = {}
    table.insert(header, "Benchmarks")
    for _, col in ipairs(columns) do
        table.insert(header, impl_names[col])
    end

    for i = 1, #header do
        header[i] = string.format("\\thead{%s}", header[i])
    end

    table.insert(parts, totexrow(header))

    table.insert(parts, "\\midrule")

    for _, test in ipairs(tests) do
        local numbers = {}
        table.insert(numbers, string.format("%-14s", test.name))
        for _, impl in ipairs(columns) do
            local s = totexstring(values[test.dir][impl])
            table.insert(numbers, string.format("%5s", s))
        end
        table.insert(parts, totexrow(numbers))
    end

    table.insert(parts, "\\bottomrule")
    table.insert(parts, "\\end{tabular}")
    table.insert(parts, "")

    return table.concat(parts, "\n")
end

local ii = require("inspect")
print("averages =", ii(averages))
print("maximums =", ii(maximums))
print("ratios =", ii(ratios))
print()
print(tex_table("AVERAGES", {"lua", "luaot", "luajit", "pallene"}, with_errors))
print(tex_table("RATIOS", {"luaot", "luajit", "pallene"}, ratios))
