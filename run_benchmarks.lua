#!/usr/bin/env lua

local lfs = require "lfs"
local chronos = require "chronos"

local util = require "titan-compiler.util"

-- run the command a single time and return the time elapsed
local function time(cmd)
    local t = chronos.nanotime()
    local result, err = util.shell(cmd .. " > /dev/null")
    local time_elapsed = chronos.nanotime() - t
    if not result then
        util.abort(err)
    end
    return time_elapsed
end

local function min(arr)
    local m = math.maxinteger
    for _, v in ipairs(arr) do
        m = math.min(m, v)
    end
    return m
end

local function measure(test_dir, name)
    local test_name = string.gsub(test_dir, "/", ".") .. "." .. name

    local lua
    if string.match(name, "^luajit") then
        lua = "luajit"
    else
        lua = "lua/src/lua"
    end

    local cmd = string.format(
            [[ %s %s/main.lua %s ]], lua, test_dir, test_name)
    print("running", cmd)
    local results = {}
    for i = 1, 3 do
        table.insert(results, time(cmd))
    end
    return min(results)
end

local function compile(ext, file_name)
    if     ext == "titan" then
        return util.shell(string.format("./titanc %s", file_name))
    elseif ext == "c" then
        return util.shell(string.format("./titanc --compile-c %s", file_name))
    elseif ext == "lua" then
        return true
    else
        return false, string.format("unknow extension: %s", ext)
    end
end

-- TODO: In the current state, this is just a `rm -rf ./*.so`, for all cases.
-- Check if we can simplify to just that or if the luajut stuff will behave
-- differently when we implement it.
local cleanup = {
    ["lua"] =
        function() end,

    ["titan"] =
        function(test_dir, name)
            os.remove(test_dir .. "/" .. name .. ".so")
        end,

    ["c"] =
        function(test_dir, name)
            os.remove(test_dir .. "/" .. name .. ".so")
        end,
}

local function benchmark(test_dir)
    local file_names = {}
    for file_name in lfs.dir(test_dir) do
        if not string.find(file_name, "^%.") and
           file_name ~= "main.lua" then
            table.insert(file_names, file_name)
        end
    end

    local results = {}
    for _, file_name in ipairs(file_names) do
        local name, ext = util.split_ext(file_name)
        local path = test_dir .. "/" .. file_name
        local ok, err = compile(ext, path)
        if not ok then
            util.abort(err)
        end
        local result = measure(test_dir, name)
        table.insert(results, {name = name, result = result})
        cleanup[ext](test_dir, name)
    end

    table.sort(results, function(r1, r2) return r1.name < r2.name end)
    for _, r in ipairs(results) do
        print(string.format("%-16s%.3f", r.name, r.result))
    end
    print("----------")
end

local function run_all_benchmarks()
    for test in lfs.dir("benchmarks") do
        if not string.find(test, "^%.") then
            local test_dir = "benchmarks/" .. test
            benchmark(test_dir)
        end
    end
end

local test_dir = arg[1]
if test_dir then
    test_dir = string.gsub(test_dir, "/*$", "")
    benchmark(test_dir)
else
    run_all_benchmarks()
end
