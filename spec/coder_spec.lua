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

describe("Titan code generator", function()
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

    it("tests integer step value in 'for'", function()
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

    it("tests integer postive literals in 'for'", function()
        local code = [[
            function forstep(): integer
                local v: integer = 0
                for i = 1, 10, 2 do
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
        local ok, err = call("titan_test", "x = titan_test.forstep();assert(x==25)")
        assert.truthy(ok, err)
    end)

    it("tests integer negative literals in 'for'", function()
        local code = [[
            function forstep(): integer
                local v: integer = 0
                for i = 10, 1, -2 do
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
        local ok, err = call("titan_test", "x = titan_test.forstep();assert(x==30)")
        assert.truthy(ok, err)
    end)

    it("tests float step value in 'for'", function()
        local code = [[
            function forstep(f: float, t: float, s: float): float
                local v: float = 0
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
        local ok, err = call("titan_test", "x = titan_test.forstep(1.5,10.5,0.5);assert(x==114.0)")
        assert.truthy(ok, err)
    end)

    it("tests float postive literals in 'for'", function()
        local code = [[
            function forstep(): float
                local v: float = 0
                for i = 1.5, 10.5, 0.5 do
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
        local ok, err = call("titan_test", "x = titan_test.forstep();assert(x==114.0)")
        assert.truthy(ok, err)
    end)

    it("tests float negative literals in 'for'", function()
        local code = [[
            function forstep(): float
                local v: float = 0
                for i = 9.5, 1.5, -0.5 do
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
        local ok, err = call("titan_test", "x = titan_test.forstep();assert(x==93.5)")
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

    it("generates code for exponentiation", function()
        local code = [[
            function power(a: float, b: float): float
                return a ^ b
            end
        ]]
        local ast, err = parser.parse(code)
        assert.truthy(ast, err)
        local ok, err = checker.check(ast, code, "test.titan")
        assert.truthy(ok, err)
        local ok, err = generate(ast, "titan_test")
        assert.truthy(ok, err)
        local ok, err = call("titan_test", "assert(titan_test.power(2,3) == 8)")
        assert.truthy(ok, err)
    end)

    it("generates code for returning 'if'", function()
        local code = [[
			function abs(x:integer): integer
    			if x < 0 then return -x end
    			return x
			end
        ]]
        local ast, err = parser.parse(code)
        assert.truthy(ast, err)
        local ok, err = checker.check("titan_test", ast, code, "test.titan")
        assert.truthy(ok, err)
        local ok, err = generate(ast, "titan_test")
        assert.truthy(ok, err)
        local ok, err = call("titan_test", "assert(titan_test.abs(-1) == 1);assert(titan_test.abs(0) == 0);assert(titan_test.abs(1) == 1)")
        assert.truthy(ok, err)
    end)

    it("generates code for 'elseif'", function()
        local code = [[
            function getval(a: integer): integer
                if a == 1 then
                    return 10
                elseif a == 2 then
                    return 20
                else
                    return 30
                end
            end
        ]]
        local ast, err = parser.parse(code)
        assert.truthy(ast, err)
        local ok, err = checker.check(ast, code, "test.titan")
        assert.truthy(ok, err)
        local ok, err = generate(ast, "titan_test")
        assert.truthy(ok, err)
        local ok, err = call("titan_test", "assert(titan_test.getval(1) == 10);assert(titan_test.getval(2) == 20);assert(titan_test.getval(3) == 30)")
        assert.truthy(ok, err)
    end)

    it("generates code for 'elseif' with overlapping conditions", function()
        local code = [[
            function getval(a: integer): integer
                local b = 0
                if a > 2 then
                    b = 10
                elseif a > 1 then
                    b = 20
                else
                    b = 30
                end
                return b
            end
        ]]
        local ast, err = parser.parse(code)
        assert.truthy(ast, err)
        local ok, err = checker.check("test", ast, code, "test.titan")
        assert.truthy(ok, err)
        local ok, err = generate(ast, "titan_test")
        assert.truthy(ok, err)
        local ok, err = call("titan_test", "assert(titan_test.getval(2) == 20);assert(titan_test.getval(3) == 10);assert(titan_test.getval(1) == 30)")
        assert.truthy(ok, err)
    end)

    it("generates code for integer module-local variables", function()
        local code = [[
            local a: integer = 1
            function geta(): integer
                return a
            end
            function seta(x: integer): nil
                a = x
            end
        ]]
        local ast, err = parser.parse(code)
        assert.truthy(ast, err)
        local ok, err = checker.check(ast, code, "test.titan")
        assert.truthy(ok, err)
        local ok, err = generate(ast, "titan_test")
        assert.truthy(ok, err)
        local ok, err = call("titan_test", "assert(titan_test.geta() == 1);titan_test.seta(2);assert(titan_test.geta() == 2)")
        assert.truthy(ok, err)
    end)

    it("generates code for float module-local variables", function()
        local code = [[
            local a: float = 1
            function geta(): float
                return a
            end
            function seta(x: float): nil
                a = x
            end
        ]]
        local ast, err = parser.parse(code)
        assert.truthy(ast, err)
        local ok, err = checker.check(ast, code, "test.titan")
        assert.truthy(ok, err)
        local ok, err = generate(ast, "titan_test")
        assert.truthy(ok, err)
        local ok, err = call("titan_test", "assert(titan_test.geta() == 1);titan_test.seta(2);assert(titan_test.geta() == 2)")
        assert.truthy(ok, err)
    end)

    it("generates code for boolean module-local variables", function()
        local code = [[
            local a: boolean = true
            function geta(): boolean
                return a
            end
            function seta(x: boolean): nil
                a = x
            end
        ]]
        local ast, err = parser.parse(code)
        assert.truthy(ast, err)
        local ok, err = checker.check(ast, code, "test.titan")
        assert.truthy(ok, err)
        local ok, err = generate(ast, "titan_test")
        assert.truthy(ok, err)
        local ok, err = call("titan_test", "assert(titan_test.geta() == true);titan_test.seta(false);assert(titan_test.geta() == false)")
        assert.truthy(ok, err)
    end)

    it("generates code for array module-local variables", function()
        local code = [[
            local a: {integer} = {}
            function len(): integer 
                return #a
            end
            function seta(x: {integer}): nil
                a = x
            end
        ]]
        local ast, err = parser.parse(code)
        assert.truthy(ast, err)
        local ok, err = checker.check(ast, code, "test.titan")
        assert.truthy(ok, err)
        local ok, err = generate(ast, "titan_test")
        assert.truthy(ok, err)
        local ok, err = call("titan_test", "assert(titan_test.len() == 0);titan_test.seta({1});assert(titan_test.len() == 1)")
        assert.truthy(ok, err)
    end)

    it("handles coercion to integer", function()
        local code = [[
            function fn(): integer
                local f: float = 1.0
                local i: integer = f
                return i
            end
        ]]
        local ast, err = parser.parse(code)
        assert.truthy(ast, err)
        local ok, err = checker.check(ast, code, "test.titan")
        assert.truthy(ok, err)
        assert.same("Exp_ToInt", ast[1].block.stats[2].exp._tag)
        local ok, err = generate(ast, "titan_test")
        assert.truthy(ok, err)
        local ok, err = call("titan_test", "local x = titan_test.fn(); assert(math.type(x) == 'integer')")
        assert.truthy(ok, err)
    end)

    it("handles unused locals", function()
        local code = [[
            function fn(): nil
                local f: float = 1.0
                local i: integer = f
            end
        ]]
        local ast, err = parser.parse(code)
        assert.truthy(ast, err)
        local ok, err = checker.check(ast, code, "test.titan")
        assert.truthy(ok, err)
        assert.same("Exp_ToInt", ast[1].block.stats[2].exp._tag)
        local ok, err = generate(ast, "titan_test")
        assert.truthy(ok, err)
    end)

    it("generates code for integer exported variables", function()
        local code = [[
            a: integer = 1
            function geta(): integer
                return a
            end
        ]]
        local ast, err = parser.parse(code)
        assert.truthy(ast, err)
        local ok, err = checker.check(ast, code, "test.titan")
        assert.truthy(ok, err)
        local ok, err = generate(ast, "titan_test")
        assert.truthy(ok, err)
        local ok, err = call("titan_test", "assert(titan_test.geta() == 1);titan_test.a = 2;assert(titan_test.geta() == 2)")
        assert.truthy(ok, err)
    end)

    it("generates code for exported float variables", function()
        local code = [[
            a: float = 1
            function geta(): float
                return a
            end
        ]]
        local ast, err = parser.parse(code)
        assert.truthy(ast, err)
        local ok, err = checker.check(ast, code, "test.titan")
        assert.truthy(ok, err)
        local ok, err = generate(ast, "titan_test")
        assert.truthy(ok, err)
        local ok, err = call("titan_test", "assert(titan_test.geta() == 1);titan_test.a = 2;assert(titan_test.geta() == 2)")
        assert.truthy(ok, err)
    end)

    it("generates code for exported boolean variables", function()
        local code = [[
            a: boolean = true
            function geta(): boolean
                return a
            end
        ]]
        local ast, err = parser.parse(code)
        assert.truthy(ast, err)
        local ok, err = checker.check(ast, code, "test.titan")
        assert.truthy(ok, err)
        local ok, err = generate(ast, "titan_test")
        assert.truthy(ok, err)
        local ok, err = call("titan_test", "assert(titan_test.geta() == true);titan_test.a = false;assert(titan_test.geta() == false)")
        assert.truthy(ok, err)
    end)

    it("generates code for exported array variables", function()
        local code = [[
            a: {integer} = {}
            function len(): integer 
                return #a
            end
        ]]
        local ast, err = parser.parse(code)
        assert.truthy(ast, err)
        local ok, err = checker.check(ast, code, "test.titan")
        assert.truthy(ok, err)
        local ok, err = generate(ast, "titan_test")
        assert.truthy(ok, err)
        local ok, err = call("titan_test", "assert(titan_test.len() == 0);titan_test.a={1};assert(titan_test.len() == 1)")
        assert.truthy(ok, err)
    end)

    it("generates code for string length", function()
        local code = [[
            function len(a: string): integer 
                return #a
            end
        ]]
        local ast, err = parser.parse(code)
        assert.truthy(ast, err)
        local ok, err = checker.check(ast, code, "test.titan")
        assert.truthy(ok, err)
        local ok, err = generate(ast, "titan_test")
        assert.truthy(ok, err)
        local ok, err = call("titan_test", "assert(titan_test.len('foobar') == 6)")
        assert.truthy(ok, err)
    end)

    it("generates code for string literals", function()
        local code = [[
            function lit(): string
                return "foo\tbar\nbaz"
            end
        ]]
        local ast, err = parser.parse(code)
        assert.truthy(ast, err)
        local ok, err = checker.check(ast, code, "test.titan")
        assert.truthy(ok, err)
        local ok, err = generate(ast, "titan_test")
        assert.truthy(ok, err)
        local ok, err = call("titan_test", "assert(titan_test.lit() == 'foo\\tbar\\nbaz')")
        assert.truthy(ok, err)
    end)

    it("generates code for string concatenation", function()
        local code = [[
            function concat(a: string): string
                return a .. "foo"
            end
        ]]
        local ast, err = parser.parse(code)
        assert.truthy(ast, err)
        local ok, err = checker.check(ast, code, "test.titan")
        assert.truthy(ok, err)
        local ok, err = generate(ast, "titan_test")
        assert.truthy(ok, err)
        local ok, err = call("titan_test", "assert(titan_test.concat('a') == 'afoo')")
        assert.truthy(ok, err)
    end)

    it("generates code for string coercion from integer", function()
        local code = [[
            function concat(a: string): string
                return a .. 2
            end
        ]]
        local ast, err = parser.parse(code)
        assert.truthy(ast, err)
        local ok, err = checker.check(ast, code, "test.titan")
        assert.truthy(ok, err)
        local ok, err = generate(ast, "titan_test")
        assert.truthy(ok, err)
        local ok, err = call("titan_test", "assert(titan_test.concat('a') == 'a2')")
        assert.truthy(ok, err)
    end)

    it("generates code for string coercion from float", function()
        local code = [[
            function concat(a: string): string
                return a .. 2.5
            end
        ]]
        local ast, err = parser.parse(code)
        assert.truthy(ast, err)
        local ok, err = checker.check(ast, code, "test.titan")
        assert.truthy(ok, err)
        local ok, err = generate(ast, "titan_test")
        assert.truthy(ok, err)
        local ok, err = call("titan_test", "assert(titan_test.concat('a') == 'a2.5')")
        assert.truthy(ok, err)
    end)

    it("generates code for string concatenation of several strings", function()
        local code = [[
            function concat(a: string, b: string, c: string, d: string, e: string): string
                return a .. b .. c .. d .. e
            end
        ]]
        local ast, err = parser.parse(code)
        assert.truthy(ast, err)
        local ok, err = checker.check(ast, code, "test.titan")
        assert.truthy(ok, err)
        local ok, err = generate(ast, "titan_test")
        assert.truthy(ok, err)
        local ok, err = call("titan_test", "assert(titan_test.concat('a','b','c','d','e') == 'abcde')")
        assert.truthy(ok, err)
    end)

    it("generates code for string concatenation resulting in long string", function()
        local code = [[
            function concat(a: string, b: string, c: string, d: string, e: string): string
                return a .. b .. c .. d .. e
            end
        ]]
        local ast, err = parser.parse(code)
        assert.truthy(ast, err)
        local ok, err = checker.check(ast, code, "test.titan")
        assert.truthy(ok, err)
        local ok, err = generate(ast, "titan_test")
        assert.truthy(ok, err)
        local ok, err = call("titan_test", "assert(titan_test.concat('aaaaaaaaaa','bbbbbbbbbb','cccccccccc','dddddddddd','eeeeeeeeee') == 'aaaaaaaaaabbbbbbbbbbccccccccccddddddddddeeeeeeeeee')")
        assert.truthy(ok, err)
    end)
end)


