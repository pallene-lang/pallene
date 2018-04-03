local ast = require "titan-compiler.ast"
local ast_iterator = require "titan-compiler.ast_iterator"
local checker = require "titan-compiler.checker"

local global_upvalues = {}

local analyze = ast_iterator.new()

-- Analyzes when global variables are used, to optimize reading and writing to
-- them. Our current approach is to store global variables in a flat (not safe
-- for space) datastructure that gets stored as an upvalue in each of our
-- functions. Functions that read or write to global variables create a
-- reference to this data structure, once at the top of the function, and
-- functions that don't use global variables do not. A further optimization
-- would be to only initialize inside the code branch using global variables, if
-- the function doesn't always use globals but we would need to test first to
-- see if this would be worth the trouble.
--
-- Sets the following fields in the AST:
--
-- _n_globals:
--     In Program node
--     Integar, how many global variables the program defines
--
-- _global_index:
--     In Toplevel value nodes (Var and Func).
--     Integer, describes the index of the variable in the upvalue table.
--
-- _referenced_globals:
--     In Toplevel.Func nodes.
--     List of integers, describes what global variables the function uses.
function global_upvalues.analyze(filename, input)
    local prog, errors = checker.check(filename, input)
    if not prog then return false, errors end
    analyze:Program(prog)
    return prog, errors
end

local function toplevel_is_value_declaration(tlnode)
    local tag = tlnode._tag
    if     tag == ast.Toplevel.Func then
        return true
    elseif tag == ast.Toplevel.Var then
        return true
    elseif tag == ast.Toplevel.Record then
        return false
    elseif tag == ast.Toplevel.Import then
        return false
    else
        error("impossible")
    end
end

function analyze:Program(prog)
    local n_globals = 0
    for _, tlnode in ipairs(prog) do
        if toplevel_is_value_declaration(tlnode) then
            tlnode._global_index = n_globals
            n_globals = n_globals + 1
        end
    end
    prog._n_globals = n_globals

    ast_iterator.default.Program(self, prog)
end

function analyze:Toplevel(tlnode)
    local tag = tlnode._tag
    if     tag == ast.Toplevel.Func then
        local referenced_globals_map = {}
        analyze:Stat(tlnode.block, referenced_globals_map)
        local referenced_globals = {}
        for index, _ in pairs(referenced_globals_map) do
            table.insert(referenced_globals, index)
        end
        table.sort(referenced_globals)
        tlnode._referenced_globals = referenced_globals
    else
        ast_iterator.default.Toplevel(self, tlnode)
    end
end

function analyze:Var(var, referenced_globals_map)
    local tag = var._tag
    if     tag == ast.Var.Name then
        local decl = var._decl
        local index = decl._global_index
        if index then
            referenced_globals_map[index] = true
        end
    else
        ast_iterator.default.Var(self, var, referenced_globals_map)
    end
end

function analyze:Exp(exp, referenced_globals_map)
    local tag = exp._tag
    if tag == ast.Exp.CallFunc then
        local fexp = exp.exp
        local fargs = exp.args

        -- Function calls with the titan calling convention bypass the C closure
        -- for the function itself.
        local is_titan_call =
            fexp._tag == ast.Exp.Var and
            fexp.var._tag == ast.Var.Name and
            fexp.var._decl._tag == ast.Toplevel.Func

        if not is_titan_call then
            analyze:Exp(fexp, referenced_globals_map)
        end
        for i = 1, #fargs do
            analyze:Exp(fargs[i], referenced_globals_map)
        end

    else
        ast_iterator.default.Exp(self, exp, referenced_globals_map)
    end
end

return global_upvalues
