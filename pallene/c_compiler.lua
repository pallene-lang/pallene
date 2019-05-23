local util = require "pallene.util"

local c_compiler = {}

c_compiler.CPPFLAGS = "-I./lua/src -I./runtime"
c_compiler.CFLAGS_BASE = "--std=c99 -g -fPIC"
c_compiler.CFLAGS_WARN = "-Wall -Wundef -Wshadow -pedantic"
c_compiler.CFLAGS_OPT = "-O2"
c_compiler.CC = "cc"

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
    local cmd = table.concat(args, " ")
    local ok = util.execute(cmd)
    if not ok then
        return false, {
            "internal error: compiler failed",
            "compilation line: " .. cmd,
        }
    end
    return true, {}
end

local function compile_c(in_filename, out_filename, extra_flags)
    return run_cc({
        c_compiler.CC,
        c_compiler.CPPFLAGS,
        c_compiler.CFLAGS_BASE,
        c_compiler.CFLAGS_WARN,
        c_compiler.CFLAGS_OPT,
        extra_flags,
        "-o", util.shell_quote(out_filename),
        util.shell_quote(in_filename),
    })
end

local function link_obj(o_filename, so_filename)
    return run_cc({
        c_compiler.CC,
        c_compiler.CFLAGS_SHARED,
        "-o", util.shell_quote(so_filename),
        util.shell_quote(o_filename),
        "runtime/pallenelib.a"
    })
end

function c_compiler.compile_c_to_s(src, dst)
    return compile_c(src, dst, "-S -fverbose-asm")
end

function c_compiler.compile_s_to_o(src, dst)
    return compile_c(src, dst, "-c")
end

function c_compiler.compile_o_to_so(src, dst)
    return link_obj(src, dst)
end

return c_compiler
