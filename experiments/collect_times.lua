#!/usr/bin/env lua
local benchlib = require "benchmarks.benchlib"
local util     = require "pallene.util"


local bench = assert(arg[1])
local nrep  = tonumber(arg[2]) or 1

local params = {}
for i = 3, #arg do
    table.insert(params, arg[i])
end


local quoted_params = {}
for i = 1, #params do
    quoted_params[i] = util.shell_quote(params[i])
end

print("Benchmark,Implementation,Time,Seq")
for _, impl in ipairs({
        "pallene",
        "lua",
        "luajit",
        "capi",
        "nocheck",}) do
    for i = 1, nrep do
        local data = benchlib.run_with_impl_name("time", bench, impl, params)
        print(table.concat({bench, impl, data.time, i}, ","))
    end
end

-- Lua/Pallene benchmarks
-- C benchmarks
-- This code duplication is a bit annoying. In the long run we should get
-- rid of these C benchmarks or have a more unified organization for these
-- benchmarks...
for i = 1, nrep do
    os.execute("cd cbenchmarks; make -q")
    local mode = benchlib.modes.time
    local cmd = string.format("./cbenchmarks/%s %s",
        util.shell_quote(bench), table.concat(quoted_params, " "))
    local data = mode.parse(mode.run(cmd))
    print(table.concat({bench, "purec", data.time, i}, ","))

end
