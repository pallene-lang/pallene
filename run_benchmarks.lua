#!/usr/bin/env lua

local lfs = require "lfs"

local c_compiler = require "titan-compiler.c_compiler"
local util = require "titan-compiler.util"

-- run the command a single time and return the time elapsed
local function time(cmd)
    local result = util.shell(
        [[ { TIMEFORMAT='%3R'; time ]].. cmd ..[[ > /dev/null; } 2>&1 ]])
    local time_elapsed = tonumber(result)
    if not time_elapsed then
        io.stderr:write(result, "\n")
        return -1
    end
    return time_elapsed
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
    return results
end

local compile = {
    ["lua"] =
        function()
            return true, {}
        end,

    ["titan"] =
        function(file_name)
            return c_compiler.compile_titan(file_name,
                    util.get_file_contents(file_name))
        end,

    ["c"] =
        function(file_name)
            return c_compiler.compile_c_file(file_name)
        end,
}

local cleanup = {
    ["lua"] =
        function() end,

    ["titan"] =
        function(test_dir, name)
            os.remove(test_dir .. "/" .. name .. ".c")
            os.remove(test_dir .. "/" .. name .. ".so")
        end,

    ["c"] =
        function(test_dir, name)
            os.remove(test_dir .. "/" .. name .. ".so")
        end,
}

local function min(arr)
    local m = math.maxinteger
    for _, v in ipairs(arr) do
        m = math.min(m, v)
    end
    return m
end

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
        local compile_ext = compile[ext]
        if not compile_ext then
            goto continue
        end
        local ok, errors = compile_ext(path)
        if ok then
            local result = min(measure(test_dir, name))
            table.insert(results, {name = name, result = result})
        end
        cleanup[ext](test_dir, name)
        if #errors > 0 then
            error(table.concat(errors, "\n"))
        end
        ::continue::
    end

    table.sort(results, function(r1, r2) return r1.name < r2.name end)
    for _, r in ipairs(results) do
        print(r.name, r.result)
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
