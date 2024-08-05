-- Copyright (c) 2020, The Pallene Developers
-- Pallene is licensed under the MIT license.
-- Please refer to the LICENSE and AUTHORS files for details
-- SPDX-License-Identifier: MIT

-- INVOKING THE C COMPILER
-- =======================
-- Functions for calling the system C compiler.
-- Currently, the MacOS functionality is not tested regularly; none of the devs
-- still use it and it is not tested by the CI. Furthermore, we do not support
-- Windows. This is unfortunate. Maybe we should give this resposibility to
-- an external library that is better at this sort of thing.
-- https://github.com/pallene-lang/pallene/issues/516

local util = require "pallene.util"

local c_compiler = {}

local CC       = os.getenv("CC")       or "cc"
local CFLAGS   = os.getenv("CFLAGS")   or "-O2"
local PTLIBDIR = os.getenv("PTLIBDIR") or "/usr/local/lib"

local function get_uname()
    local ok, err, uname = util.outputs_of_execute("uname -s")
    assert(ok, err)
    return uname
end

local CFLAGS_SHARED
if string.find(get_uname(), "Darwin") then
    CFLAGS_SHARED = "-shared -undefined dynamic_lookup"
else
    CFLAGS_SHARED = "-shared"
end

local function run_cc(args)
    local cmd = CC .. " " .. table.concat(args, " ")
    local ok = util.execute(cmd)
    if not ok then
        return false, {
            "internal error: compiler failed",
            "compilation line: " .. cmd,
        }
    end
    return true, {}
end

function c_compiler.compile_c_to_o(in_filename, out_filename)
    return run_cc({
        "-fPIC",
        CFLAGS,
        "-x c",
        "-o", util.shell_quote(out_filename),
        "-c", util.shell_quote(in_filename),
    })
end

function c_compiler.compile_o_to_so(in_filename, out_filename)
    -- There is no need to add the '-x' flag when compiling an object file without a '.o' extension.
    -- According to GCC, any file name with no recognized suffix is treated as an object file.
    return run_cc({
        CFLAGS_SHARED,
        "-o", util.shell_quote(out_filename),
        util.shell_quote(in_filename),
        "-lptracer",
        "-Wl,-rpath="..PTLIBDIR,
    })
end

return c_compiler
