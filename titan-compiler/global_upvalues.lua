local ast = require "titan-compiler.ast"
local ast_iterator = require "titan-compiler.ast_iterator"
local checker = require "titan-compiler.checker"

local global_upvalues = {}

local analyze_upvalues

-- This pass analyzes what module-level variables each Titan function needs to
-- have accessible via upvalues.
--
-- At the moment we store this global data in a single flat table and keep a
-- reference to it as the first upvalue to all the Titan closures in a module.
-- While a titan function is running, the topmost function in the Lua stack
-- (L->func) will be the "lua entry point" of the first Titan function called
-- by Lua, which is also from the same module and therefore also has a reference
-- to this module's upvalue table.
--
-- This pass sets the following fields in the AST:
--
-- _globals:
--     In Program node
--     List of Toplevel AST value nodes (Var and Func).
--
-- _global_index:
--     In Toplevel value nodes
--     Integer. The index of this node in the _globals array.
--
-- _referenced_globals:
--     In Toplevel.Func nodes.
--     List of integers, describes what global variables the function uses.
function global_upvalues.analyze(filename, input)
    local prog, errors = checker.check(filename, input)
    if not prog then return false, errors end
    analyze_upvalues(prog)
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

local function sorted_keys(obj)
    local ks = {}
    for k, _ in pairs(obj) do
        table.insert(ks, k)
    end
    table.sort(ks)
    return ks
end

local analyze = ast_iterator.new()

analyze_upvalues = function(prog)
    local globals = {}
    for _, tlnode in ipairs(prog) do
        if toplevel_is_value_declaration(tlnode) then
            local n = #globals + 1
            tlnode._global_index = n
            globals[n] = tlnode
        end
    end
    prog._globals = globals

    analyze:Program(prog, {}) -- Ignore this "referenced globals" map
end

function analyze:Toplevel(tlnode, referenced_globals_map)
    local tag = tlnode._tag
    if     tag == ast.Toplevel.Func then
        local func_referenced_globals_map = {}
        analyze:Stat(tlnode.block, func_referenced_globals_map)
        tlnode._referenced_globals = sorted_keys(func_referenced_globals_map)
    else
        ast_iterator.Toplevel(self, tlnode, referenced_globals_map)
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
        ast_iterator.Var(self, var, referenced_globals_map)
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
        ast_iterator.Exp(self, exp, referenced_globals_map)
    end
end

return global_upvalues
