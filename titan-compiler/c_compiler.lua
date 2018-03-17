local coder = require "titan-compiler.coder"
local util = require "titan-compiler.util"

local c_compiler = {}

c_compiler.LUA_SOURCE_PATH = "./lua/src"
c_compiler.CFLAGS_BASE = "--std=c99 -Wall"
c_compiler.CFLAGS_OPT = "-O2"
c_compiler.CC = "cc"

local UNAME = util.shell("uname -s")

if string.find(UNAME, "Darwin") then
    c_compiler.CFLAGS_SHARED = "-fPIC -shared -undefined dynamic_lookup"
else
    c_compiler.CFLAGS_SHARED = "-fPIC -shared"
end

function c_compiler.compile_c_file(c_filename, so_filename)
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
    local basename = assert(string.match(filename, "^(.*)%.titan$"))
    local c_filename = basename .. ".c"
    local so_filename = basename .. ".so"
    local modname = string.gsub(basename, "/", "_")

    local code, errors = coder.generate(filename, input, modname)
    if not code then return false, errors end

    local ok, err = util.set_file_contents(c_filename, code)
    if not ok then return nil, {err} end

    return c_compiler.compile_c_file(c_filename, so_filename)
end

return c_compiler
