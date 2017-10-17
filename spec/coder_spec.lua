local checker = require 'titan-compiler.checker'
local parser = require 'titan-compiler.parser'
local types = require 'titan-compiler.types'
local coder = require 'titan-compiler.coder'
local util = require 'titan-compiler.util'

local function generate(ast, modname)
    local generated_code = coder.generate(modname, ast)
    local ok, errmsg = util.set_file_contents(modname .. ".c", generated_code)
    if not ok then return ok, errmsg end
    
    local CC = "gcc"
    local CFLAGS = "--std=c99 -O2 -Wall -Ilua/src/ -fPIC"
    
    return os.execute(string.format([[
    %s %s -shared %s.c -o %s.so
    ]], CC, CFLAGS, modname, modname))
end

local function call(modname, code)
    local cmd = string.format("lua/src/lua -l %s -e \"%s\"", 
        modname, code)
    return os.execute(cmd)
end

describe("Titan code generator ", function()
    it("deletes array element", function()
        local code = [[
            function delete(array: {integer}, i: integer): nil
                array[i] = nil
            end
        ]]
        local ast, err = parser.parse(code)
        assert.truthy(ast, err)
        local ok, err = checker.check(ast, code, "test.titan")
        assert.truthy(ok, err)
        local ok, err = generate(ast, "titan_test")
        assert.truthy(ok, err)
        local ok, err = call("titan_test", "arr={1,2,3};titan_test.delete(arr,3);assert(#arr==2)")
        assert.truthy(ok, err)
    end)
end)
