#!/usr/bin/env lua

local argparse = require "argparse"
local chronos = require "chronos"
local lfs = require "lfs"

local util = require "pallene.util"

local p = argparse(arg[0], "Titan benchmarks")
p:argument("test_dir", "Only benchmark a specific directory"):args("?")
p:flag("--no-lua", "Do not run the (slow) lua benchmark")
p:option("--sort", "Sort by name or result"):count("0-1")
local args = p:parse()

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
    for i = 1, 5 do
        table.insert(results, time(cmd))
    end
    return min(results)
end

local function compile(ext, file_name)
    if     ext == "titan" then
        return util.shell(string.format("./pallenec %s", file_name))
    elseif ext == "c" then
        return util.shell(string.format("./pallenec --compile-c %s", file_name))
    elseif ext == "lua" then
        return true
    else
        return false, string.format("unknown extension: %s", ext)
    end
end

local function benchmark(test_dir)
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

        if not (ext == "lua" and lua == "lua/src/lua" and args.no_lua) then
            local result = measure(lua, test_dir, name)
            table.insert(results, {name = name, result = result})
        end
    end

    -- run luajit against *.lua if there is no luajit.lua
    local luajit_executed = false
    local lua_files = {}
    for _, file_name in ipairs(file_names) do
        local name, ext = util.split_ext(file_name)
        if name == "luajit" then
            luajit_executed = true
        elseif ext == "lua" then
            table.insert(lua_files, name)
        end
    end
    if not luajit_executed and #lua_files ~= 0 then
        for _, f in ipairs(lua_files) do
            local result = measure("luajit", test_dir, f)
            local name = f .. " luajit"
            table.insert(results, {name = name, result = result})
        end
    end

    local worst = 0
    for _, r in ipairs(results) do
        worst = math.max(worst, r.result)
    end
    local sort_func
    if args.sort == "result" then
        sort_func = function(r1, r2) return r1.result > r2.result end
    else
        sort_func = function(r1, r2) return r1.name < r2.name end
    end
    table.sort(results, sort_func)
    for _, r in ipairs(results) do
        local percent = r.result / worst
        print(string.format("%-40s%-20.3f%-20.3f", r.name, r.result, percent))
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

--
-- main
--

if args.test_dir then
    local test_dir = string.gsub(args.test_dir, "/*$", "")
    benchmark(test_dir)
else
    run_all_benchmarks()
end
