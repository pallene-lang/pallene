local util = require "pallene.util"

local c_compiler = {}

c_compiler.CC = "cc"
c_compiler.CPPFLAGS = "-I./lua/src -I./runtime"
c_compiler.CFLAGS_BASE = "-std=c99 -g -fPIC"
c_compiler.CFLAGS_WARN = "-Wall -Wundef -Wshadow -Wpedantic -Wno-unused"
c_compiler.CFLAGS_OPT = "-O2"
c_compiler.S_FLAGS = "-fverbose-asm"

local function get_uname()
    local ok, err, uname = util.outputs_of_execute("uname -s")
    assert(ok, err)
    return uname
end

if string.find(get_uname(), "Darwin") then
    c_compiler.CFLAGS_SHARED = "-shared -undefined dynamic_lookup"
else
    c_compiler.CFLAGS_SHARED = "-shared"
end

local function run_cc(args)
    local cmd = c_compiler.CC .. " " .. table.concat(args, " ")
    local ok = util.execute(cmd)
    if not ok then
        return false, {
            "internal error: compiler failed",
            "compilation line: " .. cmd,
        }
    end
    return true, {}
end

function c_compiler.compile_c_to_s(in_filename, out_filename)
    return run_cc({
        c_compiler.CPPFLAGS,
        c_compiler.CFLAGS_BASE,
        c_compiler.CFLAGS_WARN,
        c_compiler.CFLAGS_OPT,
        c_compiler.S_FLAGS,
        "-x c",
        "-o", util.shell_quote(out_filename),
        "-S", util.shell_quote(in_filename),
    })
end

function c_compiler.compile_s_to_o(in_filename, out_filename)
    return run_cc({
        "-x assembler",
        "-o", util.shell_quote(out_filename),
        "-c", util.shell_quote(in_filename),
    })

end

function c_compiler.compile_o_to_so(in_filename, out_filename)
    return run_cc({
        c_compiler.CFLAGS_SHARED,
        "-o", util.shell_quote(out_filename),
        util.shell_quote(in_filename),
        "runtime/pallenelib.a"
    })
end

return c_compiler
