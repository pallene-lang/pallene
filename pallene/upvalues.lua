local ast = require "pallene.ast"
local ast_iterator = require "pallene.ast_iterator"
local typedecl = require "pallene.typedecl"

local upvalues = {}

local analyze_upvalues

-- This pass analyzes what variables each Pallene function needs to have
-- accessible via upvalues. Those upvalues could be module varibles, string
-- literals and records metatables.
--
-- At the moment we store this global data in a single flat table and keep a
-- reference to it as the first upvalue to all the Pallene closures in a module.
-- While a pallene function is running, the topmost function in the Lua stack
-- (L->func) will be the "lua entry point" of the first Pallene function called
-- by Lua, which is also from the same module and therefore also has a reference
-- to this module's upvalue table.
--
-- This pass sets the following fields in the AST:
--
-- _upvalues:
--     In Program node
--     List of Upvalue.T:
--      - string literals
--      - Toplevel AST value nodes (Var, Func and Record).
--
-- _literals:
--     In Program node
--     Map a literal to an upvalue.
--
-- _upvalue_index:
--     In Toplevel value nodes
--     Integer. The index of this node in the _upvalues array.
function upvalues.analyze(prog_ast)
    analyze_upvalues(prog_ast)
    return prog_ast, {}
end

local function declare_type(typename, cons)
    typedecl.declare(upvalues, "upvalues", typename, cons)
end

declare_type("T", {
    Literal = {"lit"},
    ModVar  = {"tl_node"},
})

upvalues.internal_literals = {
    "__index",
    "__newindex",
    "__metatable",
}

local function toplevel_is_value_declaration(tlnode)
    local tag = tlnode._tag
    if     tag == ast.Toplevel.Func then
        return true
    elseif tag == ast.Toplevel.Var then
        return true
    elseif tag == ast.Toplevel.Record then
        return true -- metametable
    elseif tag == ast.Toplevel.Import then
        return false
    else
        error("impossible")
    end
end

local function add_literal(upvs, literals, lit)
    local n = #upvs + 1
    upvs[n] = upvalues.T.Literal(lit)
    literals[lit] = n
end

local analyze = ast_iterator.new()

analyze_upvalues = function(prog_ast)
    local upvs = {}
    local literals = {}

    -- We add internals first because other user values might need them during
    -- initalization
    for _, lit in pairs(upvalues.internal_literals) do
        add_literal(upvs, literals, lit)
    end

    for _, tlnode in ipairs(prog_ast) do
        if tlnode._tag == ast.Toplevel.Record then
            for _, field in ipairs(tlnode.field_decls) do
                add_literal(upvs, literals, field.name)
            end
        end
    end

    analyze:Program(prog_ast, upvs, literals)

    for _, tlnode in ipairs(prog_ast) do
        if toplevel_is_value_declaration(tlnode) then
            local n = #upvs + 1
            tlnode._upvalue_index = n
            upvs[n] = upvalues.T.ModVar(tlnode)
        end
    end

    prog_ast._upvalues = upvs
    prog_ast._literals = literals
end

function analyze:Exp(exp, upvs, literals)
    local tag = exp._tag
    if     tag == ast.Exp.String then
        add_literal(upvs, literals, exp.value)

    else
        ast_iterator.Exp(self, exp, upvs, literals)
    end
end

return upvalues
