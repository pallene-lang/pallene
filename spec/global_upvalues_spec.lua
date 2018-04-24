local global_upvalues = require "titan-compiler.global_upvalues"

local function run_global_upvalues(code)
    local prog, errs = global_upvalues.analyze("(global_upvalues_spec)", code)
    return prog, table.concat(errs, "\n")
end

describe("Global variable pass:", function()
    it("function without globals", function()
        local prog, errs = run_global_upvalues([[
            local function f(x: integer): integer
                return x + 1
            end
        ]])
        assert.is_truthy(prog)
        assert.equals(1, #prog._globals)
        local f = prog[1]
        assert.equals(1, f._global_index)
        assert.equals(0, #f._referenced_globals)
    end)

    it("function with globals", function()
        local prog, errs = run_global_upvalues([[
            local n: integer = 0
            local function f(): integer
                return 1 + n
            end
        ]])
        assert.is_truthy(prog)
        assert.equals(2, #prog._globals)
        local n = prog[1]
        assert.equals(1, n._global_index)
        local f = prog[2]
        assert.equals(2, f._global_index)
        assert.equals(1, #f._referenced_globals)
        assert.equals(1, f._referenced_globals[1])
    end)

    it("calling a titan function", function()
        local prog, errs = run_global_upvalues([[
            local function inc(x:integer): integer
                return x + 1
            end
            local function f(): integer
                return inc(0)
            end
        ]])
        assert.is_truthy(prog)
        assert.equals(2, #prog._globals)
        local inc = prog[1]
        assert.equals(1, inc._global_index)
        assert.equals(0, #inc._referenced_globals)
        local f = prog[2]
        assert.equals(2, f._global_index)
        assert.equals(0, #f._referenced_globals)
    end)

    it("using a titan function as first-class value", function()
        local prog, errs = run_global_upvalues([[
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
        assert.is_truthy(prog)
        assert.equals(3, #prog._globals)
        local inc = prog[1]
        assert.equals(1, inc._global_index)
        assert.equals(0, #inc._referenced_globals)
        local atzero = prog[2]
        assert.equals(2, atzero._global_index)
        assert.equals(0, #atzero._referenced_globals)
        local f = prog[3]
        assert.equals(3, f._global_index)
        assert.equals(1, #f._referenced_globals)
        assert.equals(1, f._referenced_globals[1])
    end)
end)
