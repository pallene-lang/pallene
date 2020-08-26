local chronos = require "chronos"
local util = require "pallene.util"

local benchlib = {}

benchlib.DEFAULT_LUA = "./lua/src/lua"

-- @param lua_path:       Lua interpreter to use
-- @param benchmark_path: Path to the benchmark file
--
-- Compiles the benchmark program (if necessary) and then
-- reeturns a command-line string that will run the benchmark
-- when invoked (suitable for time, perf, etc)
function benchlib.prepare_benchmark(lua_path, benchmark_path, extra_params)

    extra_params = extra_params or {}

    if benchmark_path:sub(1,2) == "./" then
        benchmark_path = benchmark_path:sub(3)
    end

    local test_dir, test_filename =
        string.match(benchmark_path, "^benchmarks/(.-)/(.-)$")
    if not test_dir then
        error("benchmark_path is not inside the benchmarks/ directory")
    end

    local basename, ext = util.split_ext(test_filename)

    -- Compile

    if ext == "pln" or ext == "c" then
        local so_name = "benchmarks/" .. test_dir .. "/" .. basename .. ".so"
        assert(util.execute(string.format(
            "make --quiet -f benchmarks/Makefile %s",
            util.shell_quote(so_name))))
    elseif ext == "lua" then
        local lua_name = "benchmarks/" .. test_dir .. "/" .. basename .. ".lua"
        assert(util.execute(string.format(
            "make --quiet -f benchmarks/Makefile %s",
            util.shell_quote(lua_name))))
    else
        error(string.format("unknown extension: %s", ext))
    end

    -- Prepare runnable command line

    local main_path =
        util.shell_quote("benchmarks" .. "/" .. test_dir .. "/" .. "main.lua")
    local modname =
        util.shell_quote("benchmarks" .. "." .. test_dir .. "." .. basename)

    local quoted_extra_params = {}
    for i = 1, #extra_params do
        quoted_extra_params[i] = util.shell_quote(extra_params[i])
    end

    local bench_cmd = string.format("%s %s %s %s",
        lua_path, main_path, modname, table.concat(quoted_extra_params, " "))

    return bench_cmd
end

--
-- Different ways to measure the benchmark commands
--
-- run: (cmd -> str)
--      Given the command line for the script to benchmark, returns the raw
--      output of the measurement utility
--
-- parse: (str -> table)
--      Extracts information from the raw measurement output into a table of
--      key-value pairs
--
benchlib.modes = {}

benchlib.modes.plain = {
    -- Return whatever the benchmark normally outputs to stdout.
    -- However, the output only appears on the screen after the benchmark has finished running.
    run = function(bench_cmd)
        local ok, err, res, _ = util.outputs_of_execute(bench_cmd)
        assert(ok, err)
        return res
    end,

    parse = function(res)
        return res
    end,
}

benchlib.modes.none = {
    -- This is similar to "plain", but the benchmark output is directly sent to the stdout, without
    -- any redirection. We can see the output being produced in real time, but the downside is that
    -- further scripts cannot read what the output was.
    run = function(bench_cmd)
        local ok, err = util.execute(bench_cmd)
        assert(ok, err)
        return ""
    end,

    parse = function(_res)
        return {}
    end,
}

benchlib.modes.time = {
    -- Measure how long it takes to run the benchmark, using /usr/bin/time.
    -- The output is rounded to 1/100 second.
    run = function(bench_cmd)
        local measure_cmd = string.format("env LC_ALL=C time -p -- %s", bench_cmd)
        local ok, err, _, res = util.outputs_of_execute(measure_cmd)
        assert(ok, err)
        return res
    end,

    parse = function(res)
        return {
            time = string.match(res, "real ([0-9.]*)")
        }
    end,
}

benchlib.modes.chronos = {
    -- Measure how long it takes to run the benchmark using chronos.nanotime.
    -- The measurement is given in microseconds, although it is probably not the best idea to trust
    -- that blindly, since there is always a lot of noise when measuring benchmarks...
    run = function(bench_cmd)
        local measure_cmd = bench_cmd
        local t1 = chronos.nanotime()
        local ok, err, _, _res = util.outputs_of_execute(measure_cmd)
        local t2 = chronos.nanotime()
        assert(ok, err)
        return string.format("%.6f", t2 - t1)
    end,

    parse = function(delta)
        return {
            time = delta,
        }
    end
}

benchlib.modes.perf = {
    -- Measure running times and a bunch of low-level info from hardware performance counters,
    -- using Linux's perf tool.
    run = function (bench_cmd)
        local measure_cmd = string.format("env LC_ALL=C perf stat -d -- %s", bench_cmd)
        local ok, err, _, res = util.outputs_of_execute(measure_cmd)
        assert(ok, err)
        return res
    end,

    parse = function(res)
        return {
            time            = string.match(res, "(%S*) *seconds time elapsed"),
            cycles          = string.match(res, "(%S*) *cycles:u"),
            ghz             = string.match(res, "cycles:u *# *(%S*) *GHz"),
            instructions    = string.match(res, "(%S*) *instructions:u"),
            IPC             = string.match(res, "(%S*) *insn per cycle"),
            branch_miss_pct = string.match(res, "branch%-misses:u *# *(.-)%%"),
            llc_miss_pct    = string.match(res, "LLC%-load%-misses:u *# *(.-)%%"),
        }
    end
}

benchlib.MODE_NAMES = {}
for name, _ in pairs(benchlib.modes) do
    table.insert(benchlib.MODE_NAMES, name)
end
table.sort(benchlib.MODE_NAMES)

--
-- For scripts that run lots of benchmarks from a same directoty
--
-- @param bench: benchmark directory name (ex.: matmul)
-- @param impl:  benchmark name           (ex.: lua, luajit, pallene)
--

function benchlib.find_benchmark(bench, impl)

    local lua_path
    local candidates

    if impl == "lua" then
        lua_path = benchlib.DEFAULT_LUA
        candidates = {
            "lua_puc.lua",
            "puc.lua",
            "lua.lua"
        }
    elseif impl == "luajit" then
        lua_path = "luajit"
        candidates = {
            "lua_luajit.lua",
            "jit.lua",
            "lua.lua"
        }
    elseif impl == "ffi" then
        lua_path = "luajit"
        candidates = {
            "ffi.lua",
        }
    else
        lua_path = benchlib.DEFAULT_LUA
        candidates = {
            impl..".lua",
            impl..".pln",
            impl..".c"
        }
    end

    for _, name in ipairs(candidates) do
        local bench_path = "benchmarks".."/"..bench.."/"..name
        local cmd = "test -e " .. util.shell_quote(bench_path)
        if os.execute(cmd) then
            return lua_path, bench_path
        end
    end

    return false, string.format("failed to find %s/%s", bench, impl)
end

function benchlib.run_with_impl_name(modename, bench, impl, extra_params)
    local mode = assert(benchlib.modes[modename])
    local lua_path, bench_path = assert(benchlib.find_benchmark(bench, impl))
    local cmd = benchlib.prepare_benchmark(lua_path, bench_path, extra_params)
    local res  = mode.run(cmd)
    local data = mode.parse(res)
    return data
end

return benchlib
