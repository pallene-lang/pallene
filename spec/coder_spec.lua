local checker = require 'titan-compiler.checker'
local parser = require 'titan-compiler.parser'
local types = require 'titan-compiler.types'
local coder = require 'titan-compiler.coder'
local util = require 'titan-compiler.util'

local function generate(ast, modname)
    os.remove(modname .. ".c")
    os.remove(modname .. ".so")
    local generated_code = coder.generate(modname, ast)
    local ok, errmsg = util.set_file_contents(modname .. ".c", generated_code)
    if not ok then return ok, errmsg end

    local CC = "gcc"
    local CFLAGS = "--std=c99 -O2 -Wall -Ilua/src/ -fPIC"

    local cc_cmd = string.format([[
        %s %s -shared %s.c lua/src/liblua.a -o %s.so
        ]], CC, CFLAGS, modname, modname)
    return os.execute(cc_cmd)
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

    it("tests nil element", function()
        local code = [[
            function testset(t: {integer}, i: integer, v: integer): integer
                if t[i] then
                  return t[i]
                else
                  t[i] = v
                  return t[i]
                end
            end
        ]]
        local ast, err = parser.parse(code)
        assert.truthy(ast, err)
        local ok, err = checker.check(ast, code, "test.titan")
        assert.truthy(ok, err)
        local ok, err = generate(ast, "titan_test")
        assert.truthy(ok, err)
        local ok, err = call("titan_test", "arr={};assert(titan_test.testset(arr,1,2)==2);assert(titan_test.testset(arr,1,3)==2)")
        assert.truthy(ok, err)
    end)

    it("tests nil element in 'while'", function()
        local code = [[
            function testfill(t: {integer}, i: integer, v: integer): nil
                while not t[i] and i > 0 do
                    t[i] = v
                    i = i - 1
                end
            end
        ]]
        local ast, err = parser.parse(code)
        assert.truthy(ast, err)
        local ok, err = checker.check(ast, code, "test.titan")
        assert.truthy(ok, err)
        local ok, err = generate(ast, "titan_test")
        assert.truthy(ok, err)
        local ok, err = call("titan_test", "arr={};titan_test.testfill(arr,5,2);assert(#arr==5)")
        assert.truthy(ok, err)
    end)

    it("tests nil element in 'repeat'", function()
        local code = [[
            function testfill(t: {integer}, i: integer, v: integer): nil
                repeat
                    t[i] = v
                    i = i - 1
                until t[i] or i == 0
            end
        ]]
        local ast, err = parser.parse(code)
        assert.truthy(ast, err)
        local ok, err = checker.check(ast, code, "test.titan")
        assert.truthy(ok, err)
        local ok, err = generate(ast, "titan_test")
        assert.truthy(ok, err)
        local ok, err = call("titan_test", "arr={};titan_test.testfill(arr,5,2);assert(#arr==5)")
        assert.truthy(ok, err)
    end)

    it("tests step value in 'for'", function()
        local code = [[
            function forstep(f: integer, t: integer, s: integer): integer
                local v: integer = 0
                for i = f, t, s do
                    v = v + i
                end
                return v
            end
        ]]
        local ast, err = parser.parse(code)
        assert.truthy(ast, err)
        local ok, err = checker.check(ast, code, "test.titan")
        assert.truthy(ok, err)
        local ok, err = generate(ast, "titan_test")
        assert.truthy(ok, err)
        local ok, err = call("titan_test", "x = titan_test.forstep(1,10,2);assert(x==25)")
        assert.truthy(ok, err)
    end)

    it("tests nil element in 'not'", function()
        local code = [[
            function testset(t: {integer}, i: integer, v: integer): integer
                if not t[i] then
                  t[i] = v
                end
                return t[i]
            end
        ]]
        local ast, err = parser.parse(code)
        assert.truthy(ast, err)
        local ok, err = checker.check(ast, code, "test.titan")
        assert.truthy(ok, err)
        local ok, err = generate(ast, "titan_test")
        assert.truthy(ok, err)
        local ok, err = call("titan_test", "arr={};assert(titan_test.testset(arr,1,2)==2);assert(titan_test.testset(arr,1,3)==2)")
        assert.truthy(ok, err)
    end)

    it("tests nil element in 'and'", function()
        local code = [[
            function testset(t: {integer}, i: integer, v: integer): integer
                if t[i] and v then
                  return t[i]
                else
                  t[i] = v
                  return t[i]
                end
            end
        ]]
        local ast, err = parser.parse(code)
        assert.truthy(ast, err)
        local ok, err = checker.check(ast, code, "test.titan")
        assert.truthy(ok, err)
        local ok, err = generate(ast, "titan_test")
        assert.truthy(ok, err)
        local ok, err = call("titan_test", "arr={};assert(titan_test.testset(arr,1,2)==2);assert(titan_test.testset(arr,1,3)==2)")
        assert.truthy(ok, err)
    end)

    it("tests nil element in 'or'", function()
        local code = [[
            function testset(t: {integer}, i: integer, v: integer): integer
                if not t[i] or not t[i] then
                  t[i] = v
                end
                return t[i]
            end
        ]]
        local ast, err = parser.parse(code)
        assert.truthy(ast, err)
        local ok, err = checker.check(ast, code, "test.titan")
        assert.truthy(ok, err)
        local ok, err = generate(ast, "titan_test")
        assert.truthy(ok, err)
        local ok, err = call("titan_test", "arr={};assert(titan_test.testset(arr,1,2)==2);assert(titan_test.testset(arr,1,3)==2)")
        assert.truthy(ok, err)
    end)

    it("tests 'or' pattern", function()
        local code = [[
            function getor(t: {integer}, i: integer, v: integer): integer
                return t[i] or v
            end
        ]]
        local ast, err = parser.parse(code)
        assert.truthy(ast, err)
        local ok, err = checker.check(ast, code, "test.titan")
        assert.truthy(ok, err)
        local ok, err = generate(ast, "titan_test")
        assert.truthy(ok, err)
        local ok, err = call("titan_test", "arr={};assert(titan_test.getor(arr,1,2)==2);arr[1]=2;assert(titan_test.getor(arr,1,3)==2)")
        assert.truthy(ok, err)
    end)

    it("tests 'and' pattern", function()
        local code = [[
            function ternary(t: {integer}, i: integer, v1: integer, v2: integer): integer
                return t[i] and v1 or v2
            end
        ]]
        local ast, err = parser.parse(code)
        assert.truthy(ast, err)
        local ok, err = checker.check(ast, code, "test.titan")
        assert.truthy(ok, err)
        local ok, err = generate(ast, "titan_test")
        assert.truthy(ok, err)
        local ok, err = call("titan_test", "arr={};assert(titan_test.ternary(arr,1,3,2)==2);arr[1]=2;assert(titan_test.ternary(arr,1,2,3)==2)")
        assert.truthy(ok, err)
    end)

    it("pass integers when expecting floats in array", function()
        local code = [[
            function sum(array: {float}): float
                local res = 0.0
                for i = 1, #array do
                    res = res + array[i]
                end
                return res
            end
        ]]
        local ast, err = parser.parse(code)
        assert.truthy(ast, err)
        local ok, err = checker.check(ast, code, "test.titan")
        assert.truthy(ok, err)
        local ok, err = generate(ast, "titan_test")
        assert.truthy(ok, err)
        local ok, err = call("titan_test", "arr={1,2,3};assert(6==titan_test.sum(arr))")
        assert.truthy(ok, err)
    end)

    it("pass integers when expecting floats in argument", function()
        local code = [[
            function sum(a: float, b: float, c: float): float
                return a + b + c
            end
        ]]
        local ast, err = parser.parse(code)
        assert.truthy(ast, err)
        local ok, err = checker.check(ast, code, "test.titan")
        assert.truthy(ok, err)
        local ok, err = generate(ast, "titan_test")
        assert.truthy(ok, err)
        local ok, err = call("titan_test", "assert(6==titan_test.sum(1,2,3))")
        assert.truthy(ok, err)
    end)
end)


