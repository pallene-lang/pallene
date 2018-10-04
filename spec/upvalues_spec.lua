local driver = require "titan-compiler.driver"
local upvalues = require "titan-compiler.upvalues"
local util = require "titan-compiler.util"

local function run_upvalues(code)
    assert(util.set_file_contents("test.titan", code))
    local prog, errs = driver.test_ast("upvalues", "test.titan")
    return prog, table.concat(errs, "\n")
end

local n_upvs = #upvalues.internal_literals

describe("Upvalues pass:", function()
    teardown(function()
        os.remove("test.titan")
    end)

    it("function without globals", function()
        local prog, errs = run_upvalues([[
            local function f(x: integer): integer
                return x + 1
            end
        ]])
        assert(prog, errs)
        assert.equals(n_upvs + 1, #prog._upvalues)
        local f = prog[1]
        assert.equals(n_upvs + 1, f._upvalue_index)
    end)

    it("function with globals", function()
        local prog, errs = run_upvalues([[
            local n: integer = 0
            local function f(): integer
                return 1 + n
            end
        ]])
        assert(prog, errs)
        assert.equals(n_upvs + 2, #prog._upvalues)
        local n = prog[1]
        assert.equals(n_upvs + 1, n._upvalue_index)
        local f = prog[2]
        assert.equals(n_upvs + 2, f._upvalue_index)
    end)

    it("calling a titan function", function()
        local prog, errs = run_upvalues([[
            local function inc(x:integer): integer
                return x + 1
            end
            local function f(): integer
                return inc(0)
            end
        ]])
        assert(prog, errs)
        assert.equals(n_upvs + 2, #prog._upvalues)
        local inc = prog[1]
        assert.equals(n_upvs + 1, inc._upvalue_index)
        local f = prog[2]
        assert.equals(n_upvs + 2, f._upvalue_index)
    end)

    it("using a titan function as first-class value", function()
        local prog, errs = run_upvalues([[
            local function inc(x: integer): integer
                return x + 1
            end
            local function atzero(h: integer -> integer): integer
                return h(0)
            end
            local function f(): integer
                return inc(atzero(inc))
            end
        ]])
        assert(prog, errs)
        assert.equals(n_upvs + 3, #prog._upvalues)
        local inc = prog[1]
        assert.equals(n_upvs + 1, inc._upvalue_index)
        local atzero = prog[2]
        assert.equals(n_upvs + 2, atzero._upvalue_index)
        local f = prog[3]
        assert.equals(n_upvs + 3, f._upvalue_index)
    end)

    it("gather literals", function()
        local prog, errs = run_upvalues([[
            local function f(): string
                return "Hello world"
            end
        ]])
        local lit = "Hello world"
        local pos = n_upvs + 1
        assert(prog, errs)
        assert.equals(n_upvs + 2, #prog._upvalues)
        assert.truthy(prog._literals)
        assert.equals(pos, prog._literals[lit])
        assert.truthy(prog._upvalues[pos])
        assert.equals(lit, prog._upvalues[pos].lit)
        local f = prog[1]
        assert.equals(n_upvs + 2, f._upvalue_index)
    end)

    it("initalize literals before variables", function()
        local prog, errs = run_upvalues([[
            local happy_face = ":)"
        ]])
        assert(prog, errs)
        assert.equals(n_upvs + 2, #prog._upvalues)
        assert.equals(upvalues.T.Literal, prog._upvalues[n_upvs + 1]._tag)
        assert.equals(upvalues.T.ModVar, prog._upvalues[n_upvs + 2]._tag)
    end)
end)
