#!/usr/bin/env lua

local c_compiler = require "titan-compiler.c_compiler"
local util = require "titan-compiler.util"

local tests = {
    "add",
}

-- run the command a single time and return the time elapsed
local function measure(cmd)
    local result = util.shell(
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
    local f = string.format("benchmarks/%s/titan.titan", test)
    local ok, err = c_compiler.compile_titan(f, util.get_file_contents(f))
    if not ok then error(table.concat(err, "\n")) end
    return benchmark(test, "titan")
end

local function benchmark_c(test)
    local basename = string.format("benchmarks/%s/c", test)
    local ok, err = c_compiler.compile_c_file(basename .. ".c",
            basename .. ".so")
    if not ok then error(table.concat(err, "\n")) end
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
