local types = require "pallene.types"
local typedecl = require "pallene.typedecl"

-- This IR is produced as a result of typechecking the parser's AST. The main
-- changes compared to the AST input are that:
--   * The toplevel is described by a Module node instead of ast.Toplevel nodes
--   * Function scopes are flattened
--   * The function bodies are first converted to typed AST nodes, and then to
--     low-level Pallene IR.
--
-- After typechecking, the body of the functions is still represented by AST
-- nodes from the parser, except that it annotates some nodes
--   * _name : in Decl.Decl and Var.Name nodes; checker.Name
--   * _type : in ast.Exp and ast.Var nodes; types.T
--
-- The next step after this is converting function bodies to a lower-level
-- Pallene intermediate representation.
--  * Function bodies are now represented as a list of Cmd nodes.
--  * The order of evaluation is explicit. Sub-expressions (except for contant
--    values) are lifted out into temporary variables.
--  * Control-flow operations are still represented as nested nodes.

local ir = {}

local function declare_type(type_name, cons)
    typedecl.declare(ir, "ir", type_name, cons)
end

function ir.Module()
    return {
        record_types = {}, -- list of Type
        functions    = {}, -- list of ir.Function
        globals      = {}, -- list of ir.VarDecl
        exports      = {}, -- list of function ids
    }
end

function ir.VarDecl(typ, comment)
    return {
        typ = typ,          -- Type
        comment = comment   -- string (variable name, location, etc)
    }
end

function ir.Function(loc, name, typ)
    return {
        loc = loc,           -- Location
        name = name,         -- string
        typ = typ,           -- Type
        vars = {},           -- list of ir.VarDecl
        body = false,        -- ast.Stat, or list of ir.Cmd
    }
end

---
--- Mutate modules
--

function ir.add_record_type(module, typ)
    table.insert(module.record_types, typ)
    return #module.record_types
end

function ir.add_function(module, loc, name, typ)
    table.insert(module.functions, ir.Function(loc, name, typ))
    return #module.functions
end

function ir.add_global(module, name, typ)
    table.insert(module.globals, ir.VarDecl(typ, name))
    return #module.globals
end

function ir.add_export(module, f_id)
    table.insert(module.exports, f_id)
end

--
-- Mutate functions
--

function ir.add_local(func, typ, comment)
    table.insert(func.vars, ir.VarDecl(typ, comment))
    return #func.vars
end

--
-- Pallene IR
--

declare_type("Value", {
    Nil        = {},
    Bool       = {"value"},
    Integer    = {"value"},
    Float      = {"value"},
    String     = {"value"},
    LocalVar   = {"id"},
    Function   = {"id"},
})

declare_type("Cmd", {
    -- Variables
    Move       = {"loc", "dst", "src"},
    GetGlobal  = {"loc", "dst", "global_id"},
    SetGlobal  = {"loc",        "global_id", "src"},

    -- Primitive Values
    Unop       = {"loc", "dst", "op", "src"},
    Binop      = {"loc", "dst", "op", "src1", "src2"},
    Concat     = {"loc", "dst", "srcs"},

    --- Dynamic Value
    ToDyn      = {"loc", "src_typ", "dst", "src"},
    FromDyn    = {"loc", "dst_typ", "dst", "src"},

    -- Arrays
    NewArr     = {"loc", "dst", "size_hint"},

    GetArr     = {"loc", "dst_typ", "dst", "src_arr", "src_i"},
    SetArr     = {"loc", "src_typ",        "src_arr", "src_i", "src_v"},

    -- Records
    NewRecord  = {"loc", "rec_typ", "dst"},

    GetField   = {"loc", "rec_typ", "dst", "src_rec", "field_name", },
    SetField   = {"loc", "rec_typ",        "src_rec", "field_name", "src_v"},

    -- Functions
    -- (dst is false if the return value is void, or unused)
    CallStatic  = {"loc", "dst", "f_id", "srcs"},
    CallDyn     = {"loc", "dst", "src_f", "srcs"},
    CallBuiltin = {"loc", "dst", "builtin_name", "srcs"},

    --
    -- Control flow
    --
    Return  = {"values"},
    BreakIf = {"condition"},
    If      = {"condition", "then_", "else_"},
    Loop    = {"cmds"},
    For     = {"loop_var", "start", "limit", "step", "body"},
})

function ir.get_srcs(cmd)
    local tag = cmd._tag

    if tag == "ir.Cmd.Return" then
        return cmd.values
    elseif tag == "ir.Cmd.BreakIf" then
        return { cmd.condition }
    elseif tag == "ir.Cmd.If" then
        return { cmd.condition }
    elseif tag == "ir.Cmd.Loop" then
        return {}
    elseif tag == "ir.Cmd.For" then
        return { cmd.start, cmd.limit, cmd.step }
    else
        local srcs = {}

        for k in ipairs({
            "src", "src1", "src2",
            "src_arr", "src_rec", "src_i", "src_v",
            "f_id",
        }) do
            if cmd[k] then
                table.insert(srcs, cmd[k])
            end
        end

        if cmd.srcs then
            for _, src in ipairs(cmd.srcs) do
                table.insert(srcs, src)
            end
        end

        return srcs
    end
end

-- Linearize the commands in a pre-order traversal. Makes it easier to iterate
-- over all commands, and is also helpful for register allocation.
function ir.flatten_cmds(root_cmds)
    local res = {}

    local do_cmds
    local do_cmd

    do_cmds = function(cmds)
        for _, cmd in ipairs(cmds) do
            do_cmd(cmd)
        end
    end

    do_cmd = function(cmd)
        table.insert(res, cmd)

        local tag = cmd._tag
        if tag == "ir.Cmd.If" then
            do_cmds(cmd.then_)
            do_cmds(cmd.else_)
        elseif tag == "ir.Cmd.Loop" then
            do_cmds(cmd.cmds)
        elseif tag == "ir.Cmd.For" then
            do_cmds(cmd.body)
        else
            -- no recursion needed
        end
    end

    do_cmds(root_cmds)
    return res
end


return ir
