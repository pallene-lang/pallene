-- Copyright (c) 2020, The Pallene Developers
-- Pallene is licensed under the MIT license.
-- Please refer to the LICENSE and AUTHORS files for details
-- SPDX-License-Identifier: MIT

local typedecl = require "pallene.typedecl"

-- Pallene IR is a lower level representation of Pallene that is easier for the optimizer and the
-- coder generator to work with.
--
-- * Each module is represented as an ir.Module
-- * Functions, global variables, records, etc are identified by a numeric ID.
-- * Function scopes are flat and local variables are identified by a numeric ID.
-- * Function bodies are represented by ir.Cmd nodes.
--
-- There is no expression-level nesting. an ir.Value can only be a variable name or a literal
-- constant. Nested subexpressions are converted into multiple commands, using temporary variables.
--
-- There is still some statement-level nesting, with if.Cmd.Loop, ir.Cmd.If, etc. We think that
-- structured control flow is easier to reason about then an unstructured control flow graph built
-- around basic blocks and gotos.

local ir = {}

local function declare_type(type_name, cons)
    typedecl.declare(ir, "ir", type_name, cons)
end

function ir.Module()
    return {
        record_types       = {}, -- list of Type
        functions          = {}, -- list of ir.Function
        globals            = {}, -- list of ir.VarDecl
        exported_functions = {}, -- list of function ids
        exported_globals   = {}, -- list of variable ids
    }
end

function ir.VarDecl(name, typ)
    return {
        name = name, -- string
        typ = typ,   -- Type
    }
end

function ir.UpvalInfo(decl, val)
    return {
        decl = decl, -- ir.VarDecl
        value = val, -- ir.Value
    }
end

function ir.Function(loc, name, typ)
    return {
        loc = loc,          -- Location
        name = name,        -- string
        typ = typ,          -- Type
        vars = {},          -- list of ir.VarDecl
        captured_vars = {}, -- list of ir.UpvalInfo
        body = false,       -- ir.Cmd
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
    table.insert(module.globals, ir.VarDecl(name, typ))
    return #module.globals
end

function ir.add_exported_function(module, f_id)
    table.insert(module.exported_functions, f_id)
end

function ir.add_exported_global(module, g_id)
    table.insert(module.exported_globals, g_id)
end

--
-- Function variables
--

function ir.add_local(func, name, typ)
    table.insert(func.vars, ir.VarDecl(name, typ))
    return #func.vars
end

function ir.add_upvalue(func, name, typ, value)
    local decl = ir.VarDecl(name, typ)
    table.insert(func.captured_vars, ir.UpvalInfo(decl, value))
    return #func.captured_vars
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
    Upvalue    = {"id"},
    Function   = {"id"},
})

-- declare_type("Cmd"
local ir_cmd_constructors = {
    -- [IMPORTANT] Please use this naming convention:
    --  - "src" fields contain an "ir.Value".
    --  - "dst" fields contain a local variable ID.

    -- Variables
    Move       = {"loc", "dst", "src"},
    GetGlobal  = {"loc", "dst", "global_id"},
    SetGlobal  = {"loc",        "global_id", "src"},

    -- Primitive Values
    Unop       = {"loc", "dst", "op", "src"},
    Binop      = {"loc", "dst", "op", "src1", "src2"},
    Concat     = {"loc", "dst", "srcs"},
    ToFloat    = {"loc", "dst", "src"},

    --- Dynamic Value
    ToDyn      = {"loc", "src_typ", "dst", "src"},
    FromDyn    = {"loc", "dst_typ", "dst", "src"},
    IsTruthy   = {"loc", "dst", "src"},
    IsNil      = {"loc", "dst", "src"},

    -- Arrays
    NewArr     = {"loc", "dst", "src_size"},

    GetArr     = {"loc", "dst_typ", "dst", "src_arr", "src_i"},
    SetArr     = {"loc", "src_typ",        "src_arr", "src_i", "src_v"},

    -- Tables
    NewTable   = {"loc", "dst", "src_size"},

    GetTable   = {"loc", "dst_typ", "dst", "src_tab", "src_k"},
    SetTable   = {"loc", "src_typ",        "src_tab", "src_k", "src_v"},

    -- Records
    NewRecord  = {"loc", "rec_typ", "dst"},

    GetField   = {"loc", "rec_typ", "dst", "src_rec", "field_name", },
    SetField   = {"loc", "rec_typ",        "src_rec", "field_name", "src_v"},

    -- Functions
    NewClosure = {"loc", "dst", "srcs", "f_id"},

    -- (dst is false if the return value is void, or unused)
    CallStatic  = {"loc", "f_typ", "dsts",  "f_id", "srcs"},
    CallDyn     = {"loc", "f_typ", "dsts", "src_f", "srcs"},

    -- Builtin operations
    BuiltinIoWrite    = {"loc",         "srcs"},
    BuiltinMathSqrt   = {"loc", "dsts", "srcs"},
    BuiltinStringChar = {"loc", "dsts", "srcs"},
    BuiltinStringSub  = {"loc", "dsts", "srcs"},
    BuiltinType       = {"loc", "dsts", "srcs"},
    BuiltinTostring   = {"loc", "dsts", "srcs"},

    --
    -- Control flow
    --
    Nop     = {},
    Seq     = {"cmds"},

    Return  = {"loc", "srcs"},
    Break   = {},
    Loop    = {"body"},

    If      = {"loc", "src_condition", "then_", "else_"},
    For     = {"loc", "dst", "src_start", "src_limit", "src_step", "body"},

    -- Garbage Collection (appears after memory allocations)
    CheckGC = {},
}
declare_type("Cmd", ir_cmd_constructors)

-- We need to know, for each kind of command, which fields contain inputs (ir.Value) and which
-- fields refer to outputs (local variable ID). We use a common naming convention for this.
local value_fields = {}
for tag, fields in pairs(ir_cmd_constructors) do
    local ff = { src = {}, srcs = {}, dst = {}, dsts = {} }
    for _, field in ipairs(fields) do
        if not field:match("_typ$") then
            if     field:match("^srcs") then table.insert(ff.srcs, field)
            elseif field:match("^src")  then table.insert(ff.src,  field)
            elseif field:match("^dsts") then table.insert(ff.dsts, field)
            elseif field:match("^dst")  then table.insert(ff.dst,  field)
            end
        end
    end
    value_fields["ir.Cmd."..tag] = ff
end

-- Returns the inputs to the given command, a list of ir.Value.
-- The order is the same order used by the constructor.
function ir.get_srcs(cmd)
    local ff = assert(value_fields[cmd._tag])
    local srcs = {}
    for _, k in ipairs(ff.src) do
        table.insert(srcs, cmd[k])
    end
    for _, k in ipairs(ff.srcs) do
        for _, src in ipairs(cmd[k]) do
            table.insert(srcs, src)
        end
    end
    return srcs
end

-- Returns the outputs of the given command, a list of local variable IDs.
-- The order is the same order used by the constructor.
function ir.get_dsts(cmd)
    local ff = assert(value_fields[cmd._tag])
    local dsts = {}
    for _, k in ipairs(ff.dst) do
        table.insert(dsts, cmd[k])
    end
    for _, k in ipairs(ff.dsts) do
        for _, dst in ipairs(cmd[k]) do
            if dst ~= false then
                table.insert(dsts, dst)
            end
        end
    end
    return dsts
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
-- If the mapping function returns a falsy value, the original version of the node is kept.
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
        local v = cmd.src_condition
        cmd.then_ = ir.clean(cmd.then_)
        cmd.else_ = ir.clean(cmd.else_)
        local t_empty = (cmd.then_._tag == "ir.Cmd.Nop")
        local e_empty = (cmd.else_._tag == "ir.Cmd.Nop")

        if t_empty and e_empty then
            return ir.Cmd.Nop()
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
