#!/usr/bin/env lua

local benchlib = require "benchmarks.benchlib"
local pretty = require "experiments.pretty_names"
local mode = benchlib.modes.perf

local nrep = tonumber(arg[1]) or 1

local bench = "matmul"

print("N,M,Implementation,Time,Cycles,Instructions,IPC,branch_miss_pct,llc_miss_pct,Seq")
for _, NM in ipairs({
    { 100, 1024 },
    { 200,  128 },
    { 400,   16 },
    { 800,    2 },
}) do
    for i = 1, nrep do
        local N = NM[1]
        local M = NM[2]

        for _, impl in ipairs({
            "pallene",
            "luajit",
            "nocheck",
        }) do
            local data = benchlib.run_with_impl_name("perf", bench, impl, NM)
            local out = {
                N, M, pretty.impl[impl],
                data.time, data.cycles, data.instructions,
                data.IPC, data.branch_miss_pct, data.llc_miss_pct,
                i
            }
            print(table.concat(out, ","))
        end
    end
end
