local scope_analysis = {}

local ast = require "titan-compiler.ast"
local location = require "titan-compiler.location"
local symtab = require "titan-compiler.symtab"
local types = require "titan-compiler.types"

local bind_names_program
local bind_names_type
local bind_names_toplevel
local bind_names_decl
local bind_names_stat
local bind_names_then
local bind_names_var
local bind_names_exp
local bind_names_args
local bind_names_field

-- Implement the lexical scoping for a Titan module.
--
-- Sets a _decl field on Var.Name and Type.Name nodes.
-- This will need to be revised when we introduce modules, because then the "."
-- will mean more than one thing (C++'s "." and "::")
--
-- @param prog AST for the whole module
-- @return true or false, followed by a list of compilation errors
function scope_analysis.bind_names(prog)
    local st = symtab.new()
    local errors = {}
    bind_names_program(prog, st, errors)
    return (#errors == 0), errors
end


--
-- Local functions
--

local function scope_error(errors, loc, fmt, ...)
    local errmsg = location.format_error(loc, fmt, ...)
    table.insert(errors, errmsg)
end

-- Return the variable name declared by a given toplevel node
local function toplevel_name(tlnode)
    local tag = tlnode._tag
    if     tag == ast.Toplevel.Func then
        return tlnode.name
    elseif tag == ast.Toplevel.Var then
        return tlnode.decl.name
    elseif tag == ast.Toplevel.Record then
        return tlnode.name
    elseif tag == ast.Toplevel.Import then
        return tlnode.localname
    else
        error("impossible")
    end
end


--
-- bind_names
--

bind_names_program = function(prog, st, errors)
    st:with_block(function()
        -- First we put all toplevel names in scope, to allow mutual references.
        -- We don't allow allow shadowing because it ambiguous with letrec and
        -- even without letrec it would still interact confusingly with module
        -- exports.
        for _, tlnode in ipairs(prog) do
            local name = toplevel_name(tlnode)
            local dup = st:find_dup(name)
            if dup then
                scope_error(errors, tlnode.loc,
                    "duplicate toplevel declaration for %s, previous one at line %d",
                    name, dup.loc.line)
            end
            st:add_symbol(name, tlnode)
        end

        -- Now we can resolve names in toplevel type annotations and in function
        -- bodies.
        for _, tlnode in ipairs(prog) do
            bind_names_toplevel(tlnode, st, errors)
        end
    end)
end

bind_names_type = function(type_node, st, errors)
    local tag = type_node._tag
    if tag == ast.Type.Nil or
            tag == ast.Type.Boolean or
            tag == ast.Type.Integer or
            tag == ast.Type.Float or
            tag == ast.Type.String then
        -- Nothing to do

    elseif tag == ast.Type.Name then
        local name = type_node.name
        type_node._decl = st:find_symbol(name) or false
        if not type_node._decl then
            scope_error(errors, type_node.loc, "type '%s' not found", name)
        end

    elseif tag == ast.Type.Array then
        bind_names_type(type_node.subtype, st, errors)

    elseif tag == ast.Type.Function then
        for _, ptype in ipairs(type_node.argtypes) do
            bind_names_type(ptype, st, errors)
        end
        for _, rettype in ipairs(type_node.rettypes) do
            bind_names_type(rettype, st, errors)
        end

    else
        error("impossible")
    end

end

bind_names_toplevel = function(tlnode, st, errors)
    local tag = tlnode._tag
    if     tag == ast.Toplevel.Func then
        for _, decl in ipairs(tlnode.params) do
            bind_names_decl(decl, st, errors)
        end
        for _, rettype in ipairs(tlnode.rettypes) do
            bind_names_type(rettype, st, errors)
        end

        st:with_block(function()
            for _, decl in ipairs(tlnode.params) do
                if st:find_dup(decl.name) then
                    scope_error(errors, decl.loc,
                        "function '%s' has multiple parameters named '%s'",
                        tlnode.name, decl.name)
                end
                st:add_symbol(decl.name, decl)
            end
            bind_names_stat(tlnode.block, st, errors)
        end)

    elseif tag == ast.Toplevel.Var then
        bind_names_decl(tlnode.decl, st, errors)
            bind_names_exp(tlnode.value, st, errors)

    elseif tag == ast.Toplevel.Record then
        for _, field_decl in ipairs(tlnode.field_decls) do
            bind_names_decl(field_decl, st, errors)
        end

    elseif tag == ast.Toplevel.Import then
        scope_error(errors, loc, "import statements are not yet implemented")

    else
        error("impossible")
    end
end

bind_names_decl = function(decl, st, errors)
    local tag = decl._tag
    if tag == ast.Decl.Decl then
        if decl.type then
            bind_names_type(decl.type, st, errors)
        end
    else
        error("impossible")
    end
end

bind_names_stat = function(stat, st, errors)
    local tag = stat._tag
    if     tag == ast.Stat.Block then
        st:with_block(function()
            for _, inner_stat in ipairs(stat.stats) do
                bind_names_stat(inner_stat, st, errors)
            end
        end)

    elseif tag == ast.Stat.While then
        bind_names_exp(stat.condition, st, errors)
        bind_names_stat(stat.block, st, errors)

    elseif tag == ast.Stat.Repeat then
        assert(stat.block._tag == ast.Stat.Block)
        st:with_block(function()
            for _, inner_stat in ipairs(stat.block.stats) do
                bind_names_stat(inner_stat, st, errors)
            end
            bind_names_exp(stat.condition, st, errors)
        end)

    elseif tag == ast.Stat.If then
        for _, then_ in ipairs(stat.thens) do
            bind_names_then(then_, st, errors)
        end
        if stat.elsestat then
            bind_names_stat(stat.elsestat, st, errors)
        end

    elseif tag == ast.Stat.For then
        bind_names_decl(stat.decl, st, errors)
        bind_names_exp(stat.start, st, errors)
        bind_names_exp(stat.finish, st, errors)
        if stat.inc then
            bind_names_exp(stat.inc, st, errors)
        end
        st:with_block(function()
            st:add_symbol(stat.decl.name, stat.decl)
            bind_names_stat(stat.block, st, errors)
        end)

    elseif tag == ast.Stat.Assign then
        bind_names_var(stat.var, st, errors)
        bind_names_exp(stat.exp, st, errors)

    elseif tag == ast.Stat.Decl then
        bind_names_decl(stat.decl, st, errors)
        bind_names_exp(stat.exp, st, errors)
        st:add_symbol(stat.decl.name, stat.decl)

    elseif tag == ast.Stat.Call then
        bind_names_exp(stat.callexp, st, errors)

    elseif tag == ast.Stat.Return then
        bind_names_exp(stat.exp, st, errors)

    else
        error("impossible")
    end
end

bind_names_then = function(then_, st, errors)
    local tag = then_._tag
    if tag == ast.Then.Then then
        bind_names_exp(then_.condition, st, errors)
        bind_names_stat(then_.block, st, errors)
    else
        error("impossible")
    end
end

bind_names_var = function(var, st, errors)
    local tag = var._tag
    if     tag == ast.Var.Name then
        var._decl = st:find_symbol(var.name) or false
        if not var._decl then
            scope_error(errors, var.loc,
                "variable '%s' not declared", var.name)
        end

    elseif tag == ast.Var.Bracket then
        bind_names_exp(var.exp1, st, errors)
        bind_names_exp(var.exp2, st, errors)

    elseif tag == ast.Var.Dot then
        bind_names_exp(var.exp, st, errors)

    else
        error("impossible")
    end
end

bind_names_exp = function(exp, st, errors)
    local tag = exp._tag
    if     tag == ast.Exp.Nil then
        -- Nothing to do

    elseif tag == ast.Exp.Bool then
        -- Nothing to do

    elseif tag == ast.Exp.Integer then
        -- Nothing to do

    elseif tag == ast.Exp.Float then
        -- Nothing to do

    elseif tag == ast.Exp.String then
        -- Nothing to do

    elseif tag == ast.Exp.Initlist then
        for _, field in ipairs(exp.fields) do
            bind_names_field(field, st, errors)
        end

    elseif tag == ast.Exp.Call then
        bind_names_exp(exp.exp, st, errors)
        bind_names_args(exp.args, st, errors)

    elseif tag == ast.Exp.Var then
        bind_names_var(exp.var, st, errors)

    elseif tag == ast.Exp.Unop then
        bind_names_exp(exp.exp, st, errors)

    elseif tag == ast.Exp.Concat then
        for _, inner_exp in ipairs(exp.exps) do
            bind_names_exp(inner_exp, st, errors)
        end

    elseif tag == ast.Exp.Binop then
        bind_names_exp(exp.lhs, st, errors)
        bind_names_exp(exp.rhs, st, errors)

    elseif tag == ast.Exp.Cast then
        bind_names_exp(exp.exp, st, errors)
        bind_names_type(exp.target, st, errors)

    else
        error("impossible")
    end
end

bind_names_args = function(args, st, errors)
    local tag = args._tag
    if     tag == ast.Args.Func then
        for _, exp in ipairs(args.args) do
            bind_names_exp(exp, st, errors)
        end

    elseif tag == ast.Args.Method then
        for _, exp in ipairs(args.args) do
            bind_names_exp(exp, st, errors)
        end

    else
        error("impossible")
    end
end

bind_names_field = function(field, st, errors)
    local tag = field._tag
    if tag == ast.Field.Field then
        bind_names_exp(field.exp, st, errors)
    else
        error("impossible")
    end
end


return scope_analysis
