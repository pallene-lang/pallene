local coder = require "titan-compiler.coder"
local util = require "titan-compiler.util"

local c_compiler = {}

c_compiler.LUA_SOURCE_PATH = "./lua/src"
c_compiler.CFLAGS_BASE = "--std=c99 -Wall -g"
c_compiler.CFLAGS_OPT = "-O2"
c_compiler.CC = "cc"

local UNAME = util.shell("uname -s")

if string.find(UNAME, "Darwin") then
    c_compiler.CFLAGS_SHARED = "-fPIC -shared -undefined dynamic_lookup"
else
    c_compiler.CFLAGS_SHARED = "-fPIC -shared"
end

function c_compiler.compile_c_file(c_filename)
    local name, ext = util.split_ext(c_filename)
    assert(ext == "c")
    local so_filename = name .. ".so"
    local args = {
        c_compiler.CC,
        c_compiler.CFLAGS_BASE,
        c_compiler.CFLAGS_OPT,
        c_compiler.CFLAGS_SHARED,
        "-I", c_compiler.LUA_SOURCE_PATH,
        "-o", so_filename,
        c_filename,
    }
    local cmd = table.concat(args, " ")
    local ok = os.execute(cmd)
    if ok then
        return true, {}
    else
        return false, {
            "internal error: gcc failed",
            "compilation line: " .. cmd,
        }
    end
end

function c_compiler.compile_titan(filename, input)
    local name, ext = util.split_ext(filename)
    assert(ext == "titan")
    local c_filename = name .. ".c"
    local modname = string.gsub(name, "/", "_")

    local code, errors = coder.generate(filename, input, modname)
    if not code then return false, errors end

    local ok, err = util.set_file_contents(c_filename, code)
    if not ok then return nil, {err} end

    return c_compiler.compile_c_file(c_filename)
end

return c_compiler
