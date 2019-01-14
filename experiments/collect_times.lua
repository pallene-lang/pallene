#!/usr/bin/env lua

local benchlib = require "benchmarks.benchlib"

local bench = assert(arg[1])
for nrep = 1, 2 do
    for _, impl in ipairs({
        "pallene",
        "lua",
        "luajit",
        "capi",
    }) do
        local data = benchlib.run_with_impl_name("chronos", bench, impl)
        print(table.concat({bench, impl, data.time}, ","))
    end
end
