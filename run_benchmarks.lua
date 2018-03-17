#!/usr/bin/env lua

local tests = {
    "add",
}

local function shell(cmd)
    local p = io.popen(cmd)
    out = p:read("*a")
    p:close()
    return out
end

local UNAME = shell("uname -s")

local SHARED
if string.find(UNAME, "Darwin") then
    SHARED = "-shared -undefined dynamic_lookup"
else
    SHARED = "-shared"
end

-- run the command a single time and return the time elapsed
local function measure(cmd)
    local result = shell(
        [[ { TIMEFORMAT='%3R'; time ]].. cmd ..[[ > /dev/null; } 2>&1 ]])
    local time_elapsed = tonumber(result)
    if not time_elapsed then
        error("Error:\n" .. result)
    end
    return time_elapsed
end

local function benchmark(test, prog)
    local cmd = string.format([[ lua/src/lua benchmarks/%s/main.lua benchmarks.%s.%s ]],
            test, test, prog)
    print("running", cmd)
    local results = {}
    for i = 1, 3 do
        table.insert(results, measure(cmd))
    end
    return results
end

local function benchmark_lua(test)
    return benchmark(test, "lua")
end

local function benchmark_titan(test)
    local compile = string.format(
        [[ ./titanc benchmarks/%s/titan.titan ]], test)
    shell(compile)
    return benchmark(test, "titan")
end

local function benchmark_c(test)
    local compile = string.format(
        [[ cc --std=c99 -O2 -Wall -fPIC %s -I lua/src -o benchmarks/%s/c.so benchmarks/%s/c.c ]],
        SHARED, test, test)
    shell(compile)
    return benchmark(test, "c")
end

local function min(arr)
    local m = math.maxinteger
    for _, v in ipairs(arr) do
        m = math.min(m, v)
    end
    return m
end

local benchmarks = {
    benchmark_lua,
    benchmark_titan,
    benchmark_c,
}

local M = {}
for _, test in ipairs(tests) do
    local line = {}
    for _, b in ipairs(benchmarks) do
        local results = b(test)
        table.insert(line, min(results))
    end
    table.insert(M, line)
end

-- TODO better formatting
print("---")
for i = 1, #M do
    io.write(tests[i], "\t")
    for j = 1, #M[i] do
        io.write(M[i][j], "\t")
    end
    io.write("\n")
end
