local benchlib = require "benchmarks.benchlib"

local tests = {
    {
        name = "Spectral Norm",
        dir  = "spectralnormGrid",
        modules = 3,
        N = 1000,
        Nsmall = 10,
    },
    {
        name = "N Queens",
        dir = "queenGrid",
        modules = 3,
        N = 13,
        Nsmall = 5,
    },
    {
        name = "N Body",
        dir = "nbodyGrid",
        modules = 3,
        N = 2000000,
        Nsmall = 200,
    },
    {
        name = "Stream Sieve",
        dir = "streamSieveGrid",
        modules = 2,
        N = 2000,
        Nsmall = 10,
    }
}

local luapath = "./lua/src/lua"
local luanames = {"injectLua", "injectLuaot"}
local nrep = 5
local size = "N"

-- Pre-compile the Luaot versions
for _, test in ipairs(tests) do
    local bpath = "benchmarks/" .. test.dir .. "/injectLuaot.c"
    benchlib.prepare_benchmark(luapath, bpath)
end

local runner = benchlib.modes.chronos

-- Run the experiments

local raw_times = {}
for _, test in ipairs(tests) do
    raw_times[test.dir] = {}
    for _, luaname in ipairs(luanames) do
        raw_times[test.dir][luaname] = {}
        for k = 1, (1 << test.modules) do
            raw_times[test.dir][luaname][k] = {}
            for rep = 1, nrep do

                local bpath = "benchmarks/" .. test.dir .. "/injectPln.pln"
                local bargs = { luaname, k-1, test[size] }
                local cmd = benchlib.prepare_benchmark(luapath, bpath, bargs)

                print("running", test.name, table.concat(bargs, "\t"), "i="..rep)

                local t = runner.parse(runner.run(cmd))
                raw_times[test.dir][luaname][k][rep] = t.time
                print(t.time)
            end
        end
    end
end

-- Compute the results

local averages = {}
for _, test in ipairs(tests) do
    averages[test.dir] = {}
    for _, luaname in ipairs(luanames) do
        averages[test.dir][luaname] = {}
        for k = 1, (1 << test.modules) do

            local sum = 0.0
            for rep = 1, 5 do
                sum = sum + tonumber(raw_times[test.dir][luaname][k][rep])
            end

            averages[test.dir][luaname][k] = sum / nrep
        end
    end
end

local ratios = {}
for _, test in ipairs(tests) do
    ratios[test.dir] = {}
    for _, luaname in ipairs(luanames) do
        ratios[test.dir][luaname] = {}
        for k = 1, (1 << test.modules) do
            ratios[test.dir][luaname][k] =
                averages[test.dir][luaname][k] / averages[test.dir][luaname][1]
        end
    end
end

local FMT_2 = [[
%% %s (%s)
\begin{tikzpicture}[column sep=1ex]
    \path
    (0,0)  node[matrix]{
        \pic{ovals={%s}}; \\ }  %% 3
    (0,-1) node[matrix]{
        \pic{ovals={%s}}; &     %% 1
        \pic{ovals={%s}};\\ }   %% 2
    (0,-2) node[matrix]{
        \pic{ovals={%s}}; \\ }  %% 0
    ;
\end{tikzpicture}

]]

local FMT_3 = [[
%% %s (%s)
\begin{tikzpicture}[column sep=1ex]
    \path
    (0,0)  node[matrix]{
        \pic{ovals={%s}}; \\ } %% 7
    (0,-1) node[matrix]{
        \pic{ovals={%s}}; &    %% 3
        \pic{ovals={%s}}; &    %% 5
        \pic{ovals={%s}};\\ }  %% 6
    (0,-2) node[matrix]{
        \pic{ovals={%s}}; &    %% 1
        \pic{ovals={%s}}; &    %% 2
        \pic{ovals={%s}};\\ }  %% 4
    (0,-3) node[matrix]{
        \pic{ovals={%s}}; \\ } %% 0
    ;
\end{tikzpicture}

]]

local function tex_figure(test, luaname, a)

    local chars
    if luaname == "injectLua" then
        chars = {"o", "*"}
    elseif luaname == "injectLuaot" then
        chars = {"@", "*"}
    else
        error("impossible")
    end

    local function o(k)
        local s = ""
        for i = 1, test.modules do
            local bit = ((k-1) & (1 << i-1)) >> (i-1)
            s = chars[bit+1] .. s
        end
        return s .. "/" .. string.format("%.2f", a[k])
    end

    if test.modules == 2 then
        return string.format(FMT_2, test.name, luaname,
                  o(4),
               o(2), o(3),
                  o(1))
    elseif test.modules == 3 then
        return string.format(FMT_3, test.name, luaname,
                  o(8),
            o(4), o(6), o(7),
            o(2), o(3), o(5),
                  o(1))
    else
        error("impossible")
    end
end



local ii = require "inspect"
print("raw_times = ", ii(raw_times))
print("averages = ", ii(averages))
print("ratios = ", ii(ratios))

print("==== GRAPHS =====")

for _, test in ipairs(tests) do
    for _, luaname in ipairs(luanames) do
        print(tex_figure(test, luaname, ratios[test.dir][luaname]))
    end
end


