-- Copyright (c) 2020, The Pallene Developers
-- Pallene is licensed under the MIT license.
-- Please refer to the LICENSE and AUTHORS files for details
-- SPDX-License-Identifier: MIT

-- PALLENE INTERMEDIATE REPRESENTATION
-- ===================================
-- A lower level representation of Pallene that is easier for the optimizer
-- and the code generator to work with.
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

local tagged_union = require "pallene.tagged_union"
local define_union = tagged_union.in_namespace(ir, "ir")

function ir.Module()
    return {
        record_types       = {},  -- list of Type
        functions          = {},  -- list of ir.Function
        exported_functions = {},  -- list of function ids
        exported_globals   = {},  -- list of variable ids
        loc_id_of_exports  = nil, -- integer
    }
end

function ir.VarDecl(name, typ)
    return {
        name = name, -- string
        typ = typ,   -- Type
    }
end

function ir.Function(loc, name, typ)
    return {
        loc = loc,            -- Location
        name = name,          -- string
        typ = typ,            -- Type
        vars = {},            -- list of ir.VarDecl
        captured_vars = {},   -- list of ir.VarDecl
        f_id_of_upvalue = {}, -- { u_id => integer }
        f_id_of_local = {},   -- { v_id => integer }
        blocks = {},          -- { ir.BasicBlock }
        ret_vars = {},        -- { v_id }, list of return variables
    }
end

--
-- Mutate modules
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

function ir.add_exported_global(module, loc_id)
    table.insert(module.exported_globals, loc_id)
end

--
-- Function variables
--

function ir.add_local(func, name, typ)
    table.insert(func.vars, ir.VarDecl(name, typ))
    return #func.vars
end

function ir.add_upvalue(func, name, typ)
    local decl = ir.VarDecl(name, typ)
    table.insert(func.captured_vars, decl)
    return #func.captured_vars
end

function ir.arg_var(func, i)
    local narg = #func.typ.arg_types
    assert(1 <= i and i <= narg)
    return i
end

function ir.add_ret_vars(func)
    for _,typ in ipairs(func.typ.ret_types) do
        local var = ir.add_local(func, false, typ)
        table.insert(func.ret_vars, var)
    end
end

--
-- Pallene IR
--

define_union("Value", {
    Nil        = {},
    Bool       = {"value"},
    Integer    = {"value"},
    Float      = {"value"},
    String     = {"value"},
    LocalVar   = {"id"},
    Upvalue    = {"id"},
})

-- define_union("Cmd"
local ir_cmd_constructors = {
    -- [IMPORTANT] Please use this naming convention:
    --  - "src" fields contain an "ir.Value".
    --  - "dst" fields contain a local variable ID.

    -- Variables
    Move       = {"loc", "dst", "src"},

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
    -- note: the reason NewClosure and InitUpvalues are separate operations is so
    -- we can create self-referential closures, for recursion or mutual recursion.
    NewClosure   = {"loc", "dst", "f_id"},
    InitUpvalues = {"loc", "src_f", "srcs", "f_id"},

    -- (dst is false if the return value is void, or unused)
    CallStatic  = {"loc", "f_typ", "dsts", "src_f", "srcs"},
    CallDyn     = {"loc", "f_typ", "dsts", "src_f", "srcs"},

    -- Builtin operations
    BuiltinIoWrite    = {"loc",         "srcs"},
    BuiltinMathAbs    = {"loc", "dsts", "srcs"},
    BuiltinMathCeil   = {"loc", "dsts", "srcs"},
    BuiltinMathFloor  = {"loc", "dsts", "srcs"},
    BuiltinMathFmod   = {"loc", "dsts", "srcs"},
    BuiltinMathExp    = {"loc", "dsts", "srcs"},
    BuiltinMathLn     = {"loc", "dsts", "srcs"},
    BuiltinMathLog    = {"loc", "dsts", "srcs"},
    BuiltinMathModf   = {"loc", "dsts", "srcs"},
    BuiltinMathPow    = {"loc", "dsts", "srcs"},
    BuiltinMathSqrt   = {"loc", "dsts", "srcs"},
    BuiltinMathSin    = {"loc", "dsts", "srcs"},
    BuiltinMathCos    = {"loc", "dsts", "srcs"},
    BuiltinMathTan    = {"loc", "dsts", "srcs"},
    BuiltinMathAsin   = {"loc", "dsts", "srcs"},
    BuiltinMathAcos   = {"loc", "dsts", "srcs"},
    BuiltinMathAtan   = {"loc", "dsts", "srcs"},
    BuiltinStringChar = {"loc", "dsts", "srcs"},
    BuiltinStringSub  = {"loc", "dsts", "srcs"},
    BuiltinType       = {"loc", "dsts", "srcs"},
    BuiltinTostring   = {"loc", "dsts", "srcs"},

    --
    -- Control flow
    --
    ForPrep    = {"loc", "dst_i", "dst_cond", "dst_iter", "dst_count",
                  "src_start", "src_limit", "src_step"},

    ForStep    = {"loc", "dst_i", "dst_cond", "dst_iter", "dst_count",
                  "src_start", "src_limit", "src_step"},

    Jmp        = {"target"},
    JmpIf      = {"loc", "src_cond", "target_true", "target_false"},

    -- Garbage Collection (appears after memory allocations)
    CheckGC = {},
}
define_union("Cmd", ir_cmd_constructors)

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


-- Returns the value field names that contain inputs and outputs (ir.Value).
function ir.get_value_field_names(cmd)
    return assert(value_fields[cmd._tag])
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

function ir.BasicBlock()
    return {
        cmds = {},           -- list of ir.Cmd
    }
end

local function is_jump(cmd)
    return cmd._tag == "ir.Cmd.Jmp" or cmd._tag == "ir.Cmd.JmpIf"
end

function ir.get_jump(block)
    local cmd = block.cmds[#block.cmds]
    if not cmd or not is_jump(cmd) then
        return false
    end
    return cmd
end

function ir.get_successor_list(block_list)
    local succ_list = {}    -- { block_id -> { block_id } }
    for i = 1, #block_list do
        succ_list[i] = {}
    end
    for block_i, block in ipairs(block_list) do
        local block_succs = succ_list[block_i]
        local jump = ir.get_jump(block)
        if jump then
            if jump._tag == "ir.Cmd.Jmp" then
                table.insert(block_succs, jump.target)
            elseif jump._tag == "ir.Cmd.JmpIf" then
                table.insert(block_succs, jump.target_true)
                table.insert(block_succs, jump.target_false)
            else
                assert(false, "not a jump command")
            end
        end
    end
    return succ_list
end

function ir.get_predecessor_list(block_list)
    local pred_list = {}    -- { block_id -> { block_id } }
    for i = 1, #block_list do
        pred_list[i] = {}
    end
    for block_i, block in ipairs(block_list) do
        local jump = ir.get_jump(block)
        if jump then
            if jump._tag == "ir.Cmd.Jmp" then
                table.insert(pred_list[jump.target], block_i)
            elseif jump._tag == "ir.Cmd.JmpIf" then
                table.insert(pred_list[jump.target_true ], block_i)
                table.insert(pred_list[jump.target_false], block_i)
            else
                assert(false, "not a jump command")
            end
        end
    end
    return pred_list
end

-- Returns list of block indices. Unreacheable blocks won't appear on the list, which means the
-- returned list might be smaller than the block list.
function ir.get_successor_depth_search_topological_sort(successor_list)
    local order = {}
    local visited = {}
    for i,_ in ipairs(successor_list) do
        visited[i] = false
    end
    local function depth_search(block_i)
        if not visited[block_i] then
            visited[block_i] = true
            local block_succs = successor_list[block_i]
            for _,succ in ipairs(block_succs) do
                depth_search(succ)
            end
            order[#order + 1] = block_i
        end
    end

    depth_search(1) -- start at "enter" block
    -- The actual block order is the reverse of what was calculated so far. We could have calculated
    -- the right order from the start, but the existence of unreacheable blocks makes it harder than
    -- usual (hence why we're doing it this way).
    local reverse_order = {}
    for i = #order, 1, -1 do
        table.insert(reverse_order, order[i])
    end

    return reverse_order
end

-- Returns list of block indices. Unreacheable blocks won't appear on the list, which means the
-- returned list might be smaller than the block list.
function ir.get_predecessor_depth_search_topological_sort(predecessor_list)
    local order = {}
    local visited = {}
    for i,_ in ipairs(predecessor_list) do
        visited[i] = false
    end
    local function depth_search(block_i)
        if not visited[block_i] then
            visited[block_i] = true
            local block_preds = predecessor_list[block_i]
            for _,pred in ipairs(block_preds) do
                depth_search(pred)
            end
            order[#order + 1] = block_i
        end
    end

    depth_search(#predecessor_list) -- start at "exit" block
    -- The actual block order is the reverse of what was calculated so far. We could have calculated
    -- the right order from the start, but the existence of unreacheable blocks makes it harder than
    -- usual (hence why we're doing it this way).
    local reverse_order = {}
    for i = #order, 1, -1 do
        table.insert(reverse_order, order[i])
    end

    return reverse_order
end

-- Iterate over the cmds of basic blocks using a naive ordering.
function ir.iter(block_list)
    local function go()
        for _,block in ipairs(block_list) do
            for _, cmd in ipairs(block.cmds) do
                coroutine.yield(cmd)
            end
        end
    end
    return coroutine.wrap(function() go() end)
end

function ir.flatten_cmd(block_list)
    local res = {}
    for _,block in ipairs(block_list) do
        for _,cmd in ipairs(block.cmds) do
            table.insert(res, cmd)
        end
    end
    return res
end

-- Remove jumps that are never taken
function ir.clean(func)
    for _, block in ipairs(func.blocks) do
        local jump = ir.get_jump(block)
        if jump and jump._tag == "ir.Cmd.JmpIf" and jump.src_cond._tag == "ir.Value.Bool" then
            assert(type(jump.src_cond.value) == "boolean")
            local new_jump
            if jump.src_cond.value then
                new_jump = ir.Cmd.Jmp(jump.target_true)
            else
                new_jump = ir.Cmd.Jmp(jump.target_false)
            end
            table.remove(block.cmds)
            table.insert(block.cmds, new_jump)
        end
    end
end

function ir.clean_all(module)
    for _, func in ipairs(module.functions) do
        ir.clean(func)
    end
end

return ir
