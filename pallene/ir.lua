-- Copyright (c) 2020, The Pallene Developers
-- Pallene is licensed under the MIT license.
-- Please refer to the LICENSE and AUTHORS files for details
-- SPDX-License-Identifier: MIT

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

function ir.VarDecl(name, typ)
    return {
        name = name, -- string
        typ = typ,   -- Type
    }
end

function ir.Function(loc, name, typ, body)
    return {
        loc = loc,           -- Location
        name = name,         -- string
        typ = typ,           -- Type
        vars = {},           -- list of ir.VarDecl
        body = body,         -- ast.Stat, or list of ir.Cmd
    }
end

---
--- Mutate modules
--

function ir.add_record_type(module, typ)
    table.insert(module.record_types, typ)
    return #module.record_types
end

function ir.add_function(module, loc, name, typ, body)
    table.insert(module.functions, ir.Function(loc, name, typ, body))
    return #module.functions
end

function ir.add_global(module, name, typ)
    table.insert(module.globals, ir.VarDecl(name, typ))
    return #module.globals
end

function ir.add_export(module, f_id)
    table.insert(module.exports, f_id)
end

--
-- Function variables
--

function ir.add_local(func, name, typ)
    table.insert(func.vars, ir.VarDecl(name, typ))
    return #func.vars
end


function ir.arg_var(func, i)
    local narg = #func.typ.arg_types
    assert(1 <= i and i <= narg)
    return i
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

-- [IMPORTANT!] After any changes to this data type, update the src_fields,
-- dst_fields, and other_fields list accordingly.
--
local ir_cmd_constructors = {
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
    IsTruthy   = {"loc", "dst", "src"},

    -- Arrays
    NewArr     = {"loc", "dst", "size_hint"},

    GetArr     = {"loc", "dst_typ", "dst", "src_arr", "src_i"},
    SetArr     = {"loc", "src_typ",        "src_arr", "src_i", "src_v"},

    -- Tables
    NewTable   = {"loc", "dst", "size_hint"},

    GetTable   = {"loc", "dst_typ", "dst", "src_tab", "src_k"},
    SetTable   = {"loc", "src_typ",        "src_tab", "src_k", "src_v"},

    -- Records
    NewRecord  = {"loc", "rec_typ", "dst"},

    GetField   = {"loc", "rec_typ", "dst", "src_rec", "field_name", },
    SetField   = {"loc", "rec_typ",        "src_rec", "field_name", "src_v"},

    -- Functions
    -- (dst is false if the return value is void, or unused)
    CallStatic  = {"loc", "f_typ", "dst", "f_id", "srcs"},
    CallDyn     = {"loc", "f_typ", "dst", "src_f", "srcs"},

    -- Builtin operations
    BuiltinIoWrite    = {"loc",        "src"},
    BuiltinMathSqrt   = {"loc", "dst", "src"},
    BuiltinStringChar = {"loc", "dst", "src"},
    BuiltinStringSub  = {"loc", "dst", "src1", "src2", "src3"},
    BuiltinToFloat    = {"loc", "dst", "src"},
    BuiltinType       = {"loc", "dst", "src"},

    --
    -- Control flow
    --
    Nop     = {},
    Seq     = {"cmds"},

    Return  = {"loc", "srcs"},
    Break   = {},
    Loop    = {"body"},

    If      = {"loc", "condition", "then_", "else_"},
    For     = {"loc", "loop_var", "start", "limit", "step", "body"},

    -- Garbage Collection (appears after memory allocations)
    CheckGC = {},
}

declare_type("Cmd", ir_cmd_constructors)
declare_type("Seq", {
    -- This level of indirection on top of a "list of commands" helps when
    -- editing the command list in-place
    Seq = {"cmds"}
})

local  src_fields = {
    "src", "src1", "src2", "src3",
    "src_arr", "src_tab", "src_rec", "src_i", "src_k", "src_v",
    "src_f",
    "condition", "start", "limit", "step" }
local srcs_fields = { "srcs" }

function ir.get_srcs(cmd)
    local srcs = {}
    for _, k in ipairs(src_fields) do
        if cmd[k] then
            table.insert(srcs, cmd[k])
        end
    end
    for _, k in ipairs(srcs_fields) do
        if cmd[k] then
            for _, src in ipairs(cmd[k]) do
                table.insert(srcs, src)
            end
        end
    end
    return srcs
end

local  dst_fields = { "dst" }
local dsts_fields = { "dsts"}

function ir.get_dsts(cmd)
    local dsts = {}
    for _, k in ipairs(dst_fields) do
        if cmd[k] then
            table.insert(dsts, cmd[k])
        end
    end
    for _, k in ipairs(dsts_fields) do
        if cmd[k] then
            for _, dst in ipairs(cmd[k]) do
                table.insert(dsts, dst)
            end
        end
    end
    return dsts
end

local other_fields = {
    "loc",
    "global_id",
    "op",
    "src_typ", "dst_typ", "rec_typ", "f_typ",
    "size_hint",
    "field_name",
    "f_id",
    "cmds", "then_", "else_",
    "typ", "loop_var", "body",
}
do
    local all_lists = {
        src_fields, srcs_fields,
        dst_fields, dsts_fields,
        other_fields
    }
    local all_fields = {}
    for _, fields in ipairs(all_lists) do
        for _, field in ipairs(fields) do
            all_fields[field] = true
        end
    end

    for ctor, params in pairs(ir_cmd_constructors) do
        for _, field in ipairs(params) do
            if not all_fields[field] then
                error(string.format("Field '%s' in %s is not accounted for",
                        field, ctor))
            end
        end
    end
end

-- Iterate over the cmds with a pre-order traversal.
function ir.iter(root_cmd)

    local function go(cmd)
        coroutine.yield(cmd)

        local tag = cmd._tag
        if     tag == "ir.Cmd.Seq" then
            for _, c in ipairs(cmd.cmds) do
                go(c)
            end
        elseif tag == "ir.Cmd.If" then
            go(cmd.then_)
            go(cmd.else_)
        elseif tag == "ir.Cmd.Loop" then
            go(cmd.body)
        elseif tag == "ir.Cmd.For" then
            go(cmd.body)
        else
            -- no recursion needed
        end
    end

    return coroutine.wrap(function()
        go(root_cmd)
    end)
end

function ir.flatten_cmd(root_cmd)
    local res = {}
    for cmd in ir.iter(root_cmd) do
        table.insert(res, cmd)
    end
    return res
end

-- Transform an ir.Cmd, via a mapping function that modifies individual nodes.
-- Returns the new root node. Child nodes are modified in-place.
-- If the mapping function returns a falsy value, the original version of the
-- node is kept.
function ir.map_cmd(root_cmd, f)
    local function go(cmd)
        -- Transform child nodes recursively
        local tag = cmd._tag
        if     tag == "ir.Cmd.Seq" then
            for i = 1, #cmd.cmds do
                cmd.cmds[i] = go(cmd.cmds[i])
            end
        elseif tag == "ir.Cmd.If" then
            cmd.then_ = go(cmd.then_)
            cmd.else_ = go(cmd.else_)
        elseif tag == "ir.Cmd.Loop" then
            cmd.body = go(cmd.body)
        elseif tag == "ir.Cmd.For" then
            cmd.body = go(cmd.body)
        else
            -- no child nodes
        end

        -- Transform parent node
        return f(cmd) or cmd
    end
    return go(root_cmd)
end

-- Remove some kinds of silly control flow
--   - Empty If
--   - if statements w/ constant condition
--   - Nop and Seq statements inside Seq
--   - Seq commands w/ no statements
--   - Seq commans w/ only one element
function ir.clean(cmd)
    local tag = cmd._tag
    if tag == "ir.Cmd.Nop" then
        return cmd

    elseif tag == "ir.Cmd.Seq" then
        local out = {}
        for _, c in ipairs(cmd.cmds) do
            c = ir.clean(c)
            if c._tag == "ir.Cmd.Nop" then
                -- skip
            elseif c._tag == "ir.Cmd.Seq" then
                for _, cc in ipairs(c.cmds) do
                    table.insert(out, cc)
                end
            else
                table.insert(out, c)
            end
        end
        if     #out == 0 then
            return ir.Cmd.Nop()
        elseif #out == 1 then
            return out[1]
        else
            return ir.Cmd.Seq(out)
        end

    elseif tag == "ir.Cmd.If" then
        local v = cmd.condition
        cmd.then_ = ir.clean(cmd.then_)
        cmd.else_ = ir.clean(cmd.else_)
        local t_empty = (cmd.then_._tag == "ir.Cmd.Nop")
        local e_empty = (cmd.else_._tag == "ir.Cmd.Nop")

        if t_empty and e_empty then
            return ir.Seq.Nop()
        elseif v._tag == "ir.Value.Bool" and v.value == true then
            return cmd.then_
        elseif v._tag == "ir.Value.Bool" and v.value == false then
            return cmd.else_
        else
            return cmd
        end

    elseif tag == "ir.Cmd.Loop" then
        cmd.body = ir.clean(cmd.body)
        return cmd

    elseif tag == "ir.Cmd.For" then
        cmd.body = ir.clean(cmd.body)
        return cmd

    else
        return cmd
    end
end

function ir.clean_all(module)
    for _, func in ipairs(module.functions) do
        func.body = ir.clean(func.body)
    end
end

return ir
