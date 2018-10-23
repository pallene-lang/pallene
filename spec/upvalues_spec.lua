local driver = require "pallene.driver"
local upvalues = require "pallene.upvalues"
local util = require "pallene.util"

local function run_upvalues(code)
    assert(util.set_file_contents("test.pallene", code))
    local prog_ast, errs = driver.test_ast("upvalues", "test.pallene")
    return prog_ast, table.concat(errs, "\n")
end

local n_upvs = #upvalues.internal_literals

describe("Upvalues pass:", function()
    teardown(function()
        os.remove("test.pallene")
    end)

    it("function without globals", function()
        local prog_ast, errs = run_upvalues([[
            local function f(x: integer): integer
                return x + 1
            end
        ]])
        assert(prog_ast, errs)
        assert.equals(n_upvs + 1, #prog_ast._upvalues)
        local f = prog_ast[1]
        assert.equals(n_upvs + 1, f._upvalue_index)
    end)

    it("function with globals", function()
        local prog_ast, errs = run_upvalues([[
            local n: integer = 0
            local function f(): integer
                return 1 + n
            end
        ]])
        assert(prog_ast, errs)
        assert.equals(n_upvs + 2, #prog_ast._upvalues)
        local n = prog_ast[1]
        assert.equals(n_upvs + 1, n._upvalue_index)
        local f = prog_ast[2]
        assert.equals(n_upvs + 2, f._upvalue_index)
    end)

    it("calling a pallene function", function()
        local prog_ast, errs = run_upvalues([[
            local function inc(x:integer): integer
                return x + 1
            end
            local function f(): integer
                return inc(0)
            end
        ]])
        assert(prog_ast, errs)
        assert.equals(n_upvs + 2, #prog_ast._upvalues)
        local inc = prog_ast[1]
        assert.equals(n_upvs + 1, inc._upvalue_index)
        local f = prog_ast[2]
        assert.equals(n_upvs + 2, f._upvalue_index)
    end)

    it("using a pallene function as first-class value", function()
        local prog_ast, errs = run_upvalues([[
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
        assert(prog_ast, errs)
        assert.equals(n_upvs + 3, #prog_ast._upvalues)
        local inc = prog_ast[1]
        assert.equals(n_upvs + 1, inc._upvalue_index)
        local atzero = prog_ast[2]
        assert.equals(n_upvs + 2, atzero._upvalue_index)
        local f = prog_ast[3]
        assert.equals(n_upvs + 3, f._upvalue_index)
    end)

    it("gather literals", function()
        local prog_ast, errs = run_upvalues([[
            local function f(): string
                return "Hello world"
            end
        ]])
        local lit = "Hello world"
        local pos = n_upvs + 1
        assert(prog_ast, errs)
        assert.equals(n_upvs + 2, #prog_ast._upvalues)
        assert.truthy(prog_ast._literals)
        assert.equals(pos, prog_ast._literals[lit])
        assert.truthy(prog_ast._upvalues[pos])
        assert.equals(lit, prog_ast._upvalues[pos].lit)
        local f = prog_ast[1]
        assert.equals(n_upvs + 2, f._upvalue_index)
    end)

    it("initalize literals before variables", function()
        local prog_ast, errs = run_upvalues([[
            local happy_face = ":)"
        ]])
        assert(prog_ast, errs)
        assert.equals(n_upvs + 2, #prog_ast._upvalues)
        assert.equals(upvalues.T.Literal, prog_ast._upvalues[n_upvs + 1]._tag)
        assert.equals(upvalues.T.ModVar, prog_ast._upvalues[n_upvs + 2]._tag)
    end)
end)
