local chronos = require "chronos"
local util = require "pallene.util"

local benchlib = {}

benchlib.DEFAULT_LUA = "./lua/src/lua"

-- @param lua_path:       Lua interpreter to use
-- @param benchmark_path: Path to th ebenchmark file
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

    if ext == "pallene" or ext == "c" then
        local so_name = "benchmarks/" .. test_dir .. "/" .. basename .. ".so"
        assert(util.execute(string.format(
            "make --quiet -f benchmarks/makefile %s",
            util.shell_quote(so_name))))
    elseif ext == "lua" then
        -- Nothing to do
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

benchlib.modes = {}

benchlib.modes.time = {
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
    run = function(bench_cmd)
        local measure_cmd = bench_cmd
        local t1 = chronos.nanotime()
        local ok, err, _, res = util.outputs_of_execute(measure_cmd)
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

return benchlib
