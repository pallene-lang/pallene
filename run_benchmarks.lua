#!/usr/bin/env lua

local argparse = require "argparse"
local chronos = require "chronos"
local lfs = require "lfs"

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

local function measure(lua, test_dir, name)
    local test_name = string.gsub(test_dir, "/", ".") .. "." .. name
    local cmd = string.format([[%s %s/main.lua %s]], lua, test_dir, test_name)
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
        return false, string.format("unknown extension: %s", ext)
    end
end

local function benchmark(test_dir, no_lua)
    local file_names = {}
    for file_name in lfs.dir(test_dir) do
        local _, ext = util.split_ext(file_name)
        if (ext == "titan" or ext == "c" or ext == "lua") and
            not string.find(file_name, "^%.") and
            file_name ~= "main.lua"
        then
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

        local lua
        if name == "luajit" then
            lua = "luajit"
        else
            lua = "lua/src/lua"
        end

        if not (ext == "lua" and no_lua) then
            local result = measure(lua, test_dir, name)
            table.insert(results, {name = name, result = result})
        end
    end

    -- run luajit against *.lua if there is no luajit.lua
    local luajit_run = false
    local lua_file = nil
    for _, file_name in ipairs(file_names) do
        local name, ext = util.split_ext(file_name)
        if name == "luajit" then
            luajit_run = true
        elseif ext == "lua" then
            lua_file = name
        end
    end
    if not luajit_run and lua_file then
        local result = measure("luajit", test_dir, lua_file)
        table.insert(results, {name = "luajit", result = result})
    end

    table.sort(results, function(r1, r2) return r1.name < r2.name end)
    for _, r in ipairs(results) do
        print(string.format("%-16s%.3f", r.name, r.result))
    end
    print("----------")
end

local function run_all_benchmarks(no_lua)
    for test in lfs.dir("benchmarks") do
        if not string.find(test, "^%.") then
            local test_dir = "benchmarks/" .. test
            benchmark(test_dir, no_lua)
        end
    end
end

--
--
--

local p = argparse(arg[0], "Titan benchmarks")
p:argument("test_dir", "Only benchmark a specific directory"):args("?")
p:flag("--no-lua", "Do not run the (slow) lua benchmark")
local args = p:parse()

if args.test_dir then
    local test_dir = string.gsub(args.test_dir, "/*$", "")
    benchmark(test_dir, args.no_lua)
else
    run_all_benchmarks(args.no_lua)
end
