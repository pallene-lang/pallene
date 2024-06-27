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
        body = false,         -- ir.Cmd
        blocks = false,       -- list of ir.BasicBlock
        ret_vars = {},        -- list of id's of return variables
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
    BuiltinStringChar = {"loc", "dsts", "srcs"},
    BuiltinStringSub  = {"loc", "dsts", "srcs"},
    BuiltinType       = {"loc", "dsts", "srcs"},
    BuiltinTostring   = {"loc", "dsts", "srcs"},

    --
    -- Control flow
    --
    Nop        = {},
    Seq        = {"cmds"},

    InitFor    = {"loc", "dst_i", "dst_cond", "dst_iter", "dst_count",
                  "src_start", "src_limit", "src_step"},

    IterFor    = {"loc", "dst_i", "dst_cond", "dst_iter", "dst_count",
                  "src_start", "src_limit", "src_step"},

    Return     = {"loc", "srcs"},
    Break      = {},
    Loop       = {"body"},

    If         = {"loc", "src_condition", "then_", "else_"},
    For        = {"loc", "dst", "src_start", "src_limit", "src_step", "body"},

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

local function JmpIfFalse(target, src_condition)
    return {
        target = target,               -- index of target basic block
        src_condition = src_condition, -- ir.Value
    }
end

function ir.BasicBlock()
    return {
        cmds = {},           -- list of ir.Cmd
        next = false,        -- index of next basic block if no conditional jump is taken
        jmp_false = false,   -- JmpIfFalse
    }
end

-- Returns list of block indices. Unreacheable blocks won't appear on the list, which means the
-- returned list might be smaller than the block list.
function ir.get_depth_search_topological_sort(block_list)
    local order = {}
    local visited = {}
    for i,_ in ipairs(block_list) do
        visited[i] = false
    end
    local function depth_search(block_i)
        if not visited[block_i] then
            visited[block_i] = true
            local block = block_list[block_i]
            if block.next  then
                depth_search(block.next)
            end
            if block.jmp_false  then
                depth_search(block.jmp_false.target)
            end
            order[#order + 1] = block_i
        end
    end

    depth_search(1)
    -- The actual block order is the reverse of what was calculated so far. We could have calculated
    -- the right order from the start, but the existence of unreacheable blocks makes it harder than
    -- usual. Hence why we're doing it this way.
    local actual_order = {}
    for i = #order, 1, -1 do
        table.insert(actual_order, order[i])
    end

    return actual_order
end

-- Iterate over the cmds of basic blocks.
function ir.iter(block_list)
    local order = ir.get_depth_search_topological_sort(block_list)
    local function go()
        for _,block_i in ipairs(order) do
            local block = block_list[block_i]
            for _, cmd in ipairs(block.cmds) do
                coroutine.yield(cmd)
            end
        end
    end
    return coroutine.wrap(function() go() end)
end

-- Iterate over the cmds with a pre-order traversal.
function ir.old_iter(root_cmd)

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

function ir.flatten_cmd(block_list)
    local res = {}
    for cmd in ir.old_iter(block_list) do
        table.insert(res, cmd)
    end
    return res
end

-- Transform an ir.Cmd, via a mapping function that modifies individual nodes.
-- If the mapping function returns a falsy value, the original version of the node is kept.
function ir.map_cmd(block_list, f)
    local visited = {}
    for i = 1, #block_list do
        visited[i] = false
    end
    local function go(block_id)
        if visited[block_id] then
            return
        end
        visited[block_id] = true
        local block = block_list[block_id]
        for i,cmd in ipairs(block.cmds) do
            block.cmds[i] = f(cmd) or cmd
        end
        if block.next then go(block.next) end
        if block.jmp_false then go(block.jmp_false.target) end
    end
    go(1)
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

-- temporary stuff
-- convert legacy intermediate representation (i.r. tree) to list of basic blocks

local types = require "pallene.types"

local function is_last_block_uninitialized(blocks)
    local b = blocks[#blocks]
    return not b.next and not b.jmp_false and #b.cmds == 0
end

local function finish_block(list)
    local b = list[#list]
    if not b.next then
        b.next = #list + 1
    end
    table.insert(list, ir.BasicBlock())
    return #list
end

local fill_blocks_with_cmd

function fill_blocks_with_cmd(func, listb, cmd)
    local blocks = listb.block_list
    local break_stack = listb.break_stack
    local tag = cmd._tag
    assert(tagged_union.typename(tag) == "ir.Cmd")
    if tag == "ir.Cmd.Seq" then
        for _, c in ipairs(cmd.cmds) do
            fill_blocks_with_cmd(func, listb, c)
        end
    elseif tag == "ir.Cmd.If" then
        local begin_if = #blocks
        finish_block(blocks)
        fill_blocks_with_cmd(func, listb, cmd.then_)
        local end_then = #blocks
        local begin_else = finish_block(blocks)
        fill_blocks_with_cmd(func, listb, cmd.else_)
        -- Only insert a new block if last block isn't empty. This saves us from having a bunch of
        -- trailing empty blocks when making a chain of "elseif" statements
        if not is_last_block_uninitialized(blocks) then
            finish_block(blocks)
        end
        local end_if = #blocks

        blocks[begin_if].jmp_false = JmpIfFalse(begin_else, cmd.src_condition)
        blocks[end_then].next = end_if
    elseif tag == "ir.Cmd.Break" then
        local id = #blocks
        finish_block(blocks)

        -- Each loop has a corresponding list of block indices that use a break statement. The
        -- different lists are kept on a stack that follows the nesting of the loops. After the
        -- generation of the blocks for a certain loop, we traverse the corresponding loop's list
        -- and set the right target for the blocks.
        assert(#break_stack > 0)
        local top_break_list = break_stack[#break_stack]
        table.insert(top_break_list, id)
    elseif tag == "ir.Cmd.Loop" then
        local break_blocks = {}
        table.insert(break_stack, break_blocks)

        local begin_loop = finish_block(blocks)
        fill_blocks_with_cmd(func, listb, cmd.body)
        local end_loop = #blocks
        local after_loop = finish_block(blocks)

        blocks[end_loop].next = begin_loop
        for _, index in ipairs(break_blocks) do
            blocks[index].next = after_loop
        end
        table.remove(break_stack)
    elseif tag == "ir.Cmd.For" then
        local dest_var = cmd.dst
        local dest_type = func.vars[dest_var].typ
        local count = ir.add_local(func, false, dest_type)
        local iter = ir.add_local(func, false, dest_type)
        local cond_enter = ir.add_local(func, false, types.T.Boolean())
        local cond_loop = ir.add_local(func, false, types.T.Boolean())
        local init_for = ir.Cmd.InitFor(
                cmd.loc, dest_var, cond_enter, iter, count,
                cmd.src_start, cmd.src_limit, cmd.src_step)
        local loop_cmd = ir.Cmd.Loop(ir.Cmd.Seq{
            cmd.body,
            ir.Cmd.IterFor(cmd.loc, dest_var, cond_loop, iter, count,
                           cmd.src_start, cmd.src_limit, cmd.src_step),
            ir.Cmd.If(cmd.loc, ir.Value.LocalVar(cond_loop), ir.Cmd.Break(), ir.Cmd.Nop()),
        })
        local if_cmd = ir.Cmd.If(cmd.loc, ir.Value.LocalVar(cond_enter), loop_cmd, ir.Cmd.Nop())
        fill_blocks_with_cmd(func, listb, init_for)
        fill_blocks_with_cmd(func, listb, if_cmd)
    elseif tag == "ir.Cmd.Return" then
        assert(#cmd.srcs <= #func.ret_vars)
        for i,src in ipairs(cmd.srcs) do
            local v = func.ret_vars[i]
            fill_blocks_with_cmd(func, listb, ir.Cmd.Move(cmd.loc, v, src))
        end
        table.insert(listb.ret_list, #blocks)
        finish_block(blocks)
    else
        local current_block = blocks[#blocks]
        table.insert(current_block.cmds, cmd)
    end
end

local function add_ret_vars(func)
    for _,typ in ipairs(func.typ.ret_types) do
        local var = ir.add_local(func, false, typ)
        table.insert(func.ret_vars, var)
    end
end

function ir.generate_basic_blocks(module)
    for _, func in ipairs(module.functions) do
        add_ret_vars(func)
        local blocks = {}
        table.insert(blocks, ir.BasicBlock()) -- first block must remain empty, it is the "entry"
                                              -- block used on the flow graph
        finish_block(blocks)
        local list_builder = {
            block_list = blocks,
            break_stack = {},
            ret_list = {},
        }
        fill_blocks_with_cmd(func, list_builder, func.body)
        local exit = finish_block(blocks) -- last block must be empty, it is the "exit" block
                                          -- used on the flow graph
        for _, ret_id in ipairs(list_builder.ret_list) do
            local ret_block = blocks[ret_id]
            ret_block.next = exit
        end
        func.blocks = blocks
    end
end

return ir
