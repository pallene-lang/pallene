local checker = require "titan-compiler.checker"
local util = require "titan-compiler.util"
local pretty = require "titan-compiler.pretty"

local coder = {}

local generate_program

function coder.generate(filename, input, modname)
    local ast, errors = checker.check(filename, input)
    if not ast then return false, errors end
    local code = generate_program(ast, modname)
    return code, errors
end

local whole_file_template = [[
#include "lua.h"
#include "lauxlib.h"
#include "lualib.h"

int luaopen_${MODNAME}(lua_State *L) {
    lua_newtable(L);
    return 1;
}
]]

generate_program = function(prog, modname)
    local code = util.render(whole_file_template, {
        MODNAME = modname,
    })
    return pretty.reindent_c(code)
end

return coder
