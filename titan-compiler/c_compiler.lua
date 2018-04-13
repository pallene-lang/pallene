local coder = require "titan-compiler.coder"
local util = require "titan-compiler.util"

local c_compiler = {}

c_compiler.CPPFLAGS = "-I./lua/src -I./runtime"
c_compiler.CFLAGS_BASE = "--std=c99 -g -fPIC"
c_compiler.CFLAGS_WARN = "-Wall -Wno-parentheses-equality"
c_compiler.CFLAGS_OPT = "-O2"
c_compiler.CC = "cc"

local UNAME = util.shell("uname -s")
if string.find(UNAME, "Darwin") then
    c_compiler.CFLAGS_SHARED = "-shared -undefined dynamic_lookup"
else
    c_compiler.CFLAGS_SHARED = "-shared"
end

local function compile_c(c_filename, out_filename, extra_flags)
    local args = {
        c_compiler.CC,
        c_compiler.CPPFLAGS,
        c_compiler.CFLAGS_BASE,
        c_compiler.CFLAGS_WARN,
        c_compiler.CFLAGS_OPT,
        extra_flags,
        "-o", out_filename,
        c_filename,
    }
    local cmd = table.concat(args, " ")
    local ok = os.execute(cmd)
    if not ok then
        return false, {
            "internal error: compiler failed",
            "compilation line: " .. cmd,
        }
    end
    return true, {}
end

local function link_obj_to_so(o_filename, so_filename)
    local args = {
        c_compiler.CC,
        c_compiler.CFLAGS_SHARED,
        "-o", so_filename,
        o_filename,
        "runtime/titanlib.a"
    }
    local cmd = table.concat(args, " ")
    local ok = os.execute(cmd)
    if not ok then
        return false, {
            "internal error: compiler failed",
            "compilation line: " .. cmd,
        }
    end
    return true, {}
end

function c_compiler.compile_titan_to_so(titan_filename, input, so_filename)
    local _, ext = util.split_ext(titan_filename)
    assert(ext == "titan")

    local ok, errs
    local c_filename = os.tmpname() .. ".c"
    local o_filename = os.tmpname() .. ".o"

    ok, errs = c_compiler.compile_titan_to_c(titan_filename, input, c_filename)
    if not ok then goto done end

    ok, errs = c_compiler.compile_c_to_obj(c_filename, o_filename)
    if not ok then goto done end

    ok, errs = link_obj_to_so(o_filename, so_filename)
    if not ok then goto done end

    ok, errs = true, {}

    ::done::
    os.remove(o_filename)
    os.remove(c_filename)
    return ok, errs
end

function c_compiler.compile_c_to_so(c_filename, so_filename)
    local _, ext = util.split_ext(c_filename)
    assert(ext == "c")

    local ok, errs
    local o_filename = os.tmpname() .. ".o"

    ok, errs = c_compiler.compile_c_to_obj(c_filename, o_filename)
    if not ok then goto done end

    ok, errs = link_obj_to_so(o_filename, so_filename)
    if not ok then goto done end

    ok, errs = true, {}

    ::done::
    os.remove(o_filename)
    return ok, errs
end

function c_compiler.compile_titan_to_c(titan_filename, input, c_filename)
    local name, ext = util.split_ext(titan_filename)
    assert(ext == "titan")

    local modname = string.gsub(name, "/", "_")
    local code, errors = coder.generate(titan_filename, input, modname)
    if not code then return false, errors end

    local ok, err = util.set_file_contents(c_filename, code)
    if not ok then return false, {err} end

    return true, {}
end

function c_compiler.compile_c_to_obj(c_filename, o_filename)
    return compile_c(c_filename, o_filename, "-c")
end

function c_compiler.compile_c_to_asm(c_filename, s_filename)
    return compile_c(c_filename, s_filename, "-S")
end



return c_compiler
