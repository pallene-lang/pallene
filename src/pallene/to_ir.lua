-- Copyright (c) 2020, The Pallene Developers
-- Pallene is licensed under the MIT license.
-- Please refer to the LICENSE and AUTHORS files for details
-- SPDX-License-Identifier: MIT

-- AST to IR
-- =========
-- This compiler pass converts the Pallene syntax tree to the low level IR.

local to_ir = {}

local ir = require "pallene.ir"
local types = require "pallene.types"
local util = require "pallene.util"
local trycatch = require "pallene.trycatch"

local tagged_union = require "pallene.tagged_union"
local define_union = tagged_union.in_namespace(to_ir, "to_ir")

define_union("LHS", {
    Local  = {"id"},
    Global = {"id"},
    Array  = {"typ", "arr", "i"},
    Table  = {"typ", "t", "field"},
    Record = {"typ", "rec", "field"},
})

define_union("Var", {
    LocalVar   = {"id"},
    Upvalue    = {"id"},
    GlobalVar  = {"id"},
})

local BlockBuilder = util.Class()

local ToIR = util.Class()

-- The Lua interpreter uses a byte sized number to refer to upvalues, and
-- therefore supports a maximum of 255. To make sure we don't overflow that limit,
-- we enforce a max upvalue count of 200 for Pallene.
local MaxUpvalueCount = 200

local function ir_error(loc, fmt, ...)
    local msg = "error: " .. loc:format_error(fmt, ...)
    trycatch.error("to_ir", msg)
end

function to_ir.convert(prog_ast)
    assert(prog_ast._tag == "ast.Program.Program")
    local ok, ret = trycatch.pcall(function()
        return ToIR.new():convert_toplevel(prog_ast.tls)
    end)

    if not ok then
        if ret.tag == "to_ir" then
            return false, { ret.msg }
        else
            error(ret)
        end
    end

    local ir_module = ret
    ir.clean_all(ir_module)
    return ir_module, {}
end

function to_ir.FuncInfo(f_id, func)
    return {
        loc_id_of_decl   = {},   -- { ast.Decl => integer }
        upval_id_of_decl = {},   -- { ast.Decl => integer }
        func             = func, -- ir.Function
        f_id             = f_id  -- integer
    }
end

--
--
--

function BlockBuilder:init(block_list)
    self.block_list = block_list -- { ir.BasicBlock }
    self.ret_list = {}           -- { block_id } ids of blocks that come from return statements
    self.break_stack = {}        -- { { block_id } } we keep track of blocks that come from break
                                 -- statements so we can reference them when leaving a loop
end

function BlockBuilder:finish_block()
    local list = self.block_list
    local b = list[#list]
    local jump = ir.get_jump(b)
    if not jump then
        self:append_cmd(ir.Cmd.Jmp(#list + 1))
    end
    table.insert(list, ir.BasicBlock())
    return #list
end

function BlockBuilder:start_block_list()
    table.insert(self.block_list, ir.BasicBlock())
end

function BlockBuilder:finish_block_list()
    local last_id = #self.block_list
    for _, ret_id in ipairs(self.ret_list) do
        local ret_block = self.block_list[ret_id]
        local jump = assert(ir.get_jump(ret_block))
        jump.target = last_id
    end
end

function BlockBuilder:append_cmd(cmd)
    local block = self.block_list[#self.block_list]
    table.insert(block.cmds, cmd)
    return cmd
end

function BlockBuilder:last_block_id()
    return #self.block_list
end

function BlockBuilder:is_last_block_uninitialized()
    local last = self.block_list[#self.block_list]
    return #last.cmds == 0
end

function BlockBuilder:enter_loop()
    local break_blocks = {}
    table.insert(self.break_stack, break_blocks)
end

function BlockBuilder:exit_loop(break_destination)
    assert(#self.break_stack > 0)
    local break_blocks = table.remove(self.break_stack)
    for _, index in ipairs(break_blocks) do
        local block = self.block_list[index]
        local jump = ir.get_jump(block)
        assert(jump)
        jump.target = break_destination
    end
end

function ToIR:init()
    -- Module-level variables
    self.module = ir.Module()
    self.rec_id_of_typ         = {} -- { types.T  => integer }
    self.fun_id_of_exp         = {} -- { ast.Exp  => integer }
    self.func_stack            = {} -- list of function to_ir.FuncInfo
    self.call_exps             = {} -- { ast.Exp.CallFunc }
    self.dsts_of_call          = {} -- { ast.Exp => { var_id } }
    self.captured_vals_of_func = {} -- { ir.Function => list of ir.Values }

    -- Maps an exported function's ID to it's local variable ID
    -- in the `$init` function.
    self.loc_id_of_exported_func = {} -- { integer => integer }
end

function ToIR:enter_function(f_id)
    -- Function-specific variables
    -- These are re-initialized each time.
    local func_info = to_ir.FuncInfo(f_id, self.module.functions[f_id])
    table.insert(self.func_stack, func_info)

    self.func           = func_info.func
    self.loc_id_of_decl = func_info.loc_id_of_decl

    local block_builder = BlockBuilder.new(self.func.blocks)
    block_builder:start_block_list()

    return block_builder
end

function ToIR:exit_function(block_builder)
    -- Create temporary destination variables for any unused function return values.
    for _, call_exp in ipairs(self.call_exps) do
        local dsts = self.dsts_of_call[call_exp]
        for i = 1, #dsts do
            if not dsts[i] then
                local typ = assert(call_exp._types[i])
                dsts[i] = ir.add_local(self.func, "$unused_ret", typ)
            end
        end
    end

    block_builder:finish_block_list()

    table.remove(self.func_stack, #self.func_stack)
    local current_func = self.func_stack[#self.func_stack]

    if current_func then
        self.func           = current_func.func
        self.loc_id_of_decl = current_func.loc_id_of_decl
    else
        self.func           = nil
        self.loc_id_of_decl = nil
    end
end

-- Returns a to_ir.Var object containing ID of `decl`.
-- If `decl` resolves to an upvalue, then it registers the upvalue in the intermediate
-- and current function.
function ToIR:resolve_variable(decl)
    assert(decl._tag == "ast.Decl.Decl"
        or decl._tag == "ast.FuncStat.FuncStat"
        or decl._tag == "ast.Var.Name")

    assert(decl.name)

    local stack_id, var
    for i = 1, #self.func_stack do
        local loc_id = self.func_stack[i].loc_id_of_decl[decl]
        local func   = self.func_stack[i].func
        if loc_id then
            if (decl._tag == "ast.FuncStat.FuncStat"
               and self.fun_id_of_exp[decl.value]
               and not func.f_id_of_local[loc_id]) then

                func.f_id_of_local[loc_id] = self.fun_id_of_exp[decl.value]
            end
            var = to_ir.Var.LocalVar(loc_id)
            stack_id = i
            break
        end
    end

    assert(var)
    assert(stack_id)
    for i = stack_id + 1, #self.func_stack do
        local func_info = self.func_stack[i]
        local func = func_info.func

        local ir_func = self.module.functions[func_info.f_id]
        local captured_vars  = self.captured_vals_of_func[ir_func]

        local u_id
        if func_info.upval_id_of_decl[decl] then
            u_id = func_info.upval_id_of_decl[decl]
        elseif var._tag == "to_ir.Var.LocalVar" then
            u_id = ir.add_upvalue(func, decl.name, decl._type)
            table.insert(captured_vars, ir.Value.LocalVar(var.id))
        elseif var._tag == "to_ir.Var.Upvalue" then
            u_id = ir.add_upvalue(func, decl.name, decl._type)
            table.insert(captured_vars, ir.Value.Upvalue(var.id))
        else
            tagged_union.error(var._tag)
        end

        if u_id > MaxUpvalueCount then
            ir_error(decl.loc, "too many upvalues (limit is %d)", MaxUpvalueCount)
        end

        func_info.upval_id_of_decl[decl] = u_id
        var = to_ir.Var.Upvalue(u_id)

        if (decl._tag == "ast.FuncStat.FuncStat"
            and self.fun_id_of_exp[decl.value]
            and not func.f_id_of_upvalue[u_id]) then
            func.f_id_of_upvalue[u_id] = self.fun_id_of_exp[decl.value]
        end
    end

    return var
end

function ToIR:register_lambda(exp, name)
    assert(exp._tag == "ast.Exp.Lambda")
    assert(not self.fun_id_of_exp[exp])
    local f_id = ir.add_function(self.module, exp.loc, name, exp._type)

    local ir_func = self.module.functions[f_id]
    self.captured_vals_of_func[ir_func] = {}

    self.fun_id_of_exp[exp] = f_id
    return f_id
end

-- Exports the `func_or_var` by adding it to the module exports table.
-- This must be called while generating IR for the `$init` function.
-- @param func_or_var An ir.Function or ir.Variable representing the to-be-exported value.
-- @param loc_id Local variable ID of the to-be-exported function or variable in `$init`.
function ToIR:export_local(bb, func_or_var, loc_id)
    assert(#self.func_stack == 1)

    local tv = ir.Value.LocalVar(self.module.loc_id_of_exports)
    local kv = ir.Value.String(assert(func_or_var.name))
    local fv = ir.Value.LocalVar(loc_id)
    local src_typ = assert(func_or_var.typ)
    bb:append_cmd(ir.Cmd.SetTable(func_or_var.loc, src_typ, tv, kv, fv))
end

function ToIR:convert_toplevel(prog_ast)

    -- Create the $init function (it must have ID = 1)
    local id = ir.add_function(self.module, false, "$init", types.T.Function({}, {types.T.Table({})}))
    local init_func = self.module.functions[id]
    self.captured_vals_of_func[init_func] = {}

    -- Initialize the module-level variables
    local bb = self:enter_function(1)

    local n_exports = 0
    for _, tl_node in ipairs(prog_ast) do
        local tag = tl_node._tag
        if tag == "ast.Toplevel.Stats" then
            for _, stat in ipairs(tl_node.stats) do
                local stag = stat._tag
                if     stag == "ast.Stat.Assign" then
                    for _, var in ipairs(stat.vars) do
                        if var._exported_as then
                            assert(var._type)
                            local loc_id = ir.add_local(self.func, var.name, var._type)
                            self.loc_id_of_decl[var] = loc_id
                            ir.add_exported_global(self.module, loc_id)
                            n_exports = n_exports + 1
                        end
                    end

                elseif stag == "ast.Stat.Functions" then
                    for _, func in ipairs(stat.funcs) do
                        local f_id = self:register_lambda(func.value, func.name)
                        if func.module then
                            n_exports = n_exports + 1
                            ir.add_exported_function(self.module, f_id)
                        end
                    end
                end
            end
        elseif tag == "ast.Toplevel.Typealias" then
            --skip
        elseif tag == "ast.Toplevel.Record" then
            local typ = tl_node._type
            self.rec_id_of_typ[typ] = ir.add_record_type(self.module, typ)
        else
            tagged_union.error(tag)
        end
    end

    for _, tl_node in ipairs(prog_ast) do
        if tl_node._tag == "ast.Toplevel.Stats" then
            for _, stat in ipairs(tl_node.stats) do
                self:convert_stat(bb, stat)
            end
        else
            -- skip
        end
    end

    -- Initialize the module exports as a lua table
    local exports_type  = types.T.Table({})
    self.module.loc_id_of_exports = ir.add_local(self.func, "$exports", exports_type)
    bb:append_cmd(ir.Cmd.NewTable(self.func.loc,
                                  self.module.loc_id_of_exports,
                                  ir.Value.Integer(n_exports)))
    bb:append_cmd(ir.Cmd.CheckGC)

    -- export the functions
    for _, f_id in ipairs(self.module.exported_functions) do
        local func   = self.module.functions[f_id]
        local loc_id = assert(self.loc_id_of_exported_func[f_id])
        self:export_local(bb, func, loc_id)
    end

    -- export module variables
    for _, loc_id in ipairs(self.module.exported_globals) do
        local var  = self.func.vars[loc_id]
        self:export_local(bb, var, loc_id)
    end

    local v_exports = ir.Value.LocalVar(self.module.loc_id_of_exports)
    ir.add_ret_vars(self.func)
    self:insert_return(bb, self.func.loc, {v_exports})

    self:exit_function(bb)

    return self.module
end

function ToIR:insert_return(bb, loc, src_list)
    assert(#src_list <= #self.func.ret_vars)
    for i,src in ipairs(src_list) do
        local v = self.func.ret_vars[i]
        bb:append_cmd(ir.Cmd.Move(loc, v, src))
    end
    table.insert(bb.ret_list, bb:last_block_id())
    bb:finish_block()
end


function ToIR:convert_stats(bb, stats)
    for i = 1, #stats do
        self:convert_stat(bb, stats[i])
    end
end

-- Converts a typechecked ast.Stat into commands inside basic blocks
function ToIR:convert_stat(bb, stat)
    local tag = stat._tag
    if     tag == "ast.Stat.Block" then
        self:convert_stats(bb, stat.stats)

    elseif tag == "ast.Stat.While" then
        bb:enter_loop()
        local loop_begin = bb:finish_block()
        local cond     = self:exp_to_value(bb, stat.condition)
        local cond_bool = self:value_is_truthy(bb, stat.condition, cond)
        local step_test_jmpIf = bb:append_cmd(ir.Cmd.JmpIf(stat.loc, cond_bool, nil, nil))
        local loop_body = bb:finish_block()
        self:convert_stat(bb, stat.block)
        bb:append_cmd(ir.Cmd.Jmp(loop_begin))
        local after_loop = bb:finish_block()
        step_test_jmpIf.target_true  = loop_body
        step_test_jmpIf.target_false = after_loop
        bb:exit_loop(after_loop)

    elseif tag == "ast.Stat.Repeat" then
        bb:enter_loop()
        local loop_begin = bb:finish_block()
        self:convert_stat(bb, stat.block)
        local cond     = self:exp_to_value(bb, stat.condition)
        local cond_bool = self:value_is_truthy(bb, stat.condition, cond)
        local loop_end_jmpIf = bb:append_cmd(ir.Cmd.JmpIf(stat.loc, cond_bool, nil, nil))
        local after_loop = bb:finish_block()
        loop_end_jmpIf.target_true  = after_loop
        loop_end_jmpIf.target_false = loop_begin
        bb:exit_loop(after_loop)

    elseif tag == "ast.Stat.If" then
        local cond = self:exp_to_value(bb, stat.condition)
        local cond_bool = self:value_is_truthy(bb, stat.condition, cond)
        local if_begin_jmpIf = bb:append_cmd(ir.Cmd.JmpIf(stat.loc, cond_bool, nil, nil))
        local then_begin = bb:finish_block()
        self:convert_stat(bb, stat.then_)
        local then_end_jmp = bb:append_cmd(ir.Cmd.Jmp(nil))
        local else_begin = bb:finish_block()
        self:convert_stat(bb, stat.else_)
        -- Only insert a new block if last block isn't empty. This saves us from having a bunch of
        -- trailing empty blocks when making a chain of "elseif" statements
        if not bb:is_last_block_uninitialized() then
            bb:finish_block()
        end
        local if_end = bb:last_block_id()

        if_begin_jmpIf.target_true  = then_begin
        if_begin_jmpIf.target_false = else_begin
        then_end_jmp.target = if_end

    elseif tag == "ast.Stat.ForNum" then
        local start = self:exp_to_value(bb, stat.start)
        local limit = self:exp_to_value(bb, stat.limit)
        local step  = self:exp_to_value(bb, stat.step)

        local decl = stat.decl
        local v = ir.add_local(self.func, decl.name, decl._type)
        local v_type = decl._type
        self.loc_id_of_decl[decl] = v

        local count = ir.add_local(self.func, false, v_type)
        local iter = ir.add_local(self.func, false, v_type)
        local cond_enter = ir.add_local(self.func, false, types.T.Boolean)
        local cond_loop = ir.add_local(self.func, false, types.T.Boolean)

        local init_for = ir.Cmd.ForPrep(
                stat.loc, v, cond_enter, iter, count,
                start, limit, step)
        local iter_for = ir.Cmd.ForStep(
                stat.loc, v, cond_loop, iter, count,
                start, limit, step)

        bb:append_cmd(init_for)
        bb:enter_loop()
        local before_loop_jmpIf = bb:append_cmd(ir.Cmd.JmpIf(stat.loc, ir.Value.LocalVar(cond_enter), nil, nil))
        local loop_begin = bb:finish_block()
        self:convert_stat(bb, stat.block)
        bb:append_cmd(iter_for)
        local step_test_jmpIf = bb:append_cmd(ir.Cmd.JmpIf(stat.loc, ir.Value.LocalVar(cond_loop), nil, nil))
        local after_loop = bb:finish_block()

        before_loop_jmpIf.target_true  = loop_begin
        before_loop_jmpIf.target_false = after_loop

        step_test_jmpIf.target_true  = after_loop
        step_test_jmpIf.target_false = loop_begin

        bb:exit_loop(after_loop)

    elseif tag == "ast.Stat.ForIn" then
        local decls = stat.decls
        local exps = stat.exps

        local e1 = exps[1]
        local is_ipairs = (
            e1._tag == "ast.Exp.CallFunc" and
            e1.exp._tag == "ast.Exp.Var" and
            e1.exp.var._def._tag == "typechecker.Def.Builtin" and
            e1.exp.var._def.id == "ipairs")

        bb:enter_loop()
        local step_test_jmpIf -- ir.Cmd.JmpIf of block that tests if it should break loop
        local after_loop           -- first block outside loop after loop body
        local after_step_test      -- first block after block that tests loop breaking
        if is_ipairs then
            -- `ipairs` are desugared down to regular for-loops
            -- ```
            -- for i: T1, x: T2 in ipairs(xs) do
            --   <loop body>
            -- end
            -- ```
            -- would get compiled down to:
            -- ```
            -- local i_num: integer = 1
            -- while true do
            --   local x_dyn = xs[i_num]
            --   if x_dyn == nil then
            --     break
            --   end
            --   local i = i_num as T1
            --   local x = x_dyn as T2
            --   <loop body>
            --   i_num = i_num + 1
            -- end
            -- ```


            local ipairs_args = exps[2].call_exp.args
            assert(#ipairs_args == 1)
            assert(#decls == 2)

            -- the table passed as argument to `ipairs`
            local arr =  ipairs_args[1]
            assert(types.equals(arr._type, types.T.Array(types.T.Any)))
            local v_arr = ir.add_local(self.func, "$xs", arr._type)
            self:exp_to_assignment(bb, v_arr, arr)

            -- local i_num: integer = 1
            local v_inum = ir.add_local(self.func, "$"..decls[1].name.."_num", types.T.Integer)
            local start = ir.Value.Integer(1)
            bb:append_cmd(ir.Cmd.Move(stat.loc, v_inum, start))

            local loop_begin = bb:finish_block()

            -- x_dyn = xs[i_num]
            local v_x_dyn = ir.add_local(self.func, "$"..decls[2].name.."_dyn", types.T.Any)
            local src_arr =  ir.Value.LocalVar(v_arr)
            local src_i =  ir.Value.LocalVar(v_inum)
            bb:append_cmd(ir.Cmd.GetArr(stat.loc, types.T.Any, v_x_dyn, src_arr, src_i))

            -- if x_dyn == nil then break end
            local cond_checknil = ir.add_local(self.func, false, types.T.Boolean)
            bb:append_cmd(ir.Cmd.IsNil(stat.loc, cond_checknil, ir.Value.LocalVar(v_x_dyn)))
            step_test_jmpIf= bb:append_cmd(
                    ir.Cmd.JmpIf(stat.loc, ir.Value.LocalVar(cond_checknil), nil, nil))
            after_step_test = bb:finish_block()

            -- local i: T1 = i_num as T1
            local v_i = ir.add_local(self.func, decls[1].name, decls[1]._type)
            self.loc_id_of_decl[decls[1]] = v_i
            if decls[1]._type._tag == "types.T.Integer" then
                bb:append_cmd(ir.Cmd.Move(stat.loc, v_i, ir.Value.LocalVar(v_inum)))
            else
                bb:append_cmd(ir.Cmd.ToDyn(stat.loc, types.T.Integer, v_i, ir.Value.LocalVar(v_inum)))
            end

            -- local x = x_dyn as T2
            local v_x = ir.add_local(self.func, decls[2].name, decls[2]._type)
            self.loc_id_of_decl[decls[2]] = v_x
            if decls[2]._type._tag == "types.T.Any" then
                bb:append_cmd(ir.Cmd.Move(stat.loc, v_x, ir.Value.LocalVar(v_x_dyn)))
            else
                bb:append_cmd(ir.Cmd.FromDyn(stat.loc, decls[2]._type, v_x, ir.Value.LocalVar(v_x_dyn)))
            end

            -- <loop body>
            self:convert_stat(bb, stat.block)
            -- i_num = i_num + 1
            local loop_step = ir.Value.Integer(1)
            bb:append_cmd(ir.Cmd.Binop(stat.loc, v_inum, "IntAdd", ir.Value.LocalVar(v_inum), loop_step))
            bb:append_cmd(ir.Cmd.Jmp(loop_begin))
            after_loop = bb:finish_block()
        else

            -- Regular for-in loops are desugared into regurlar loops before compiling.
            -- For example, a loop like this:
            --- ```
            -- for a: T1, b: T2 in <RHS> do
            --     <loop body>
            -- end
            ---```
            -- is compiled as if the following was written instead:
            --```
            -- local iter, st, a_dyn, b_dyn
            -- iter, st, ctrl = RHS[1], RHS[2], RHS[3]
            -- while true do
            --   a_dyn, b_dyn = iter(st, a_dyn)
            --   if a_dyn == nil then break end
            --   local a = a_dyn as T1
            --   local b = b_dyn as T2
            --   <loop body>
            -- end
            -- ```

            local v_iter = ir.add_local(self.func, "$iter", exps[1]._type)
            self:exp_to_assignment(bb, v_iter, exps[1])
            local v_state = ir.add_local(self.func, "$st", exps[2]._type)
            self:exp_to_assignment(bb, v_state, exps[2])

            local v_lhs_dyn = {}
            for _, decl in ipairs(decls) do
                local v = ir.add_local(self.func, "$" .. decl.name .. "_dyn", types.T.Any)
                table.insert(v_lhs_dyn, v)
            end

            local v_ctrl = v_lhs_dyn[1]
            self:exp_to_assignment(bb, v_ctrl, exps[3])

            --Body of the `while` loop.
            local loop_begin = bb:finish_block()
            local itertype = exps[1]._type
            local args = { ir.Value.LocalVar(v_state), ir.Value.LocalVar(v_ctrl) }
            bb:append_cmd(ir.Cmd.CallDyn(exps[1].loc, itertype, v_lhs_dyn, ir.Value.LocalVar(v_iter), args))

            -- if i == nil then break end
            local cond_checknil = ir.add_local(self.func, false, types.T.Boolean)
            bb:append_cmd(ir.Cmd.IsNil(stat.loc, cond_checknil, ir.Value.LocalVar(v_lhs_dyn[1])))
            step_test_jmpIf = bb:append_cmd(
                    ir.Cmd.JmpIf(stat.loc, ir.Value.LocalVar(cond_checknil), nil, nil))
            after_step_test = bb:finish_block()

            -- cast loop LHS to annotated types.
            for i, decl in ipairs(decls) do
                if decl._type.tag == "types.T.Any" then
                    self.loc_id_of_decl[decl] = v_lhs_dyn[i]
                else
                    local v_typed = ir.add_local(self.func, decl.name, decl._type)
                    local val = ir.Value.LocalVar(v_lhs_dyn[i])
                    bb:append_cmd(ir.Cmd.FromDyn(stat.loc, decl._type, v_typed, val))
                    self.loc_id_of_decl[decl] = v_typed
                end
            end

            self:convert_stat(bb, stat.block)
            bb:append_cmd(ir.Cmd.Jmp(loop_begin))
            after_loop = bb:finish_block()
        end

        step_test_jmpIf.target_true  = after_loop
        step_test_jmpIf.target_false = after_step_test
        bb:exit_loop(after_loop)

    elseif tag == "ast.Stat.Assign" then
        local loc = stat.loc
        local vars = stat.vars
        local exps = stat.exps

        assert(#vars <= #exps)

        -- Multiple Assignments
        -- --------------------
        -- According to the Lua reference manual, the expressions in a multiple assignment should be
        -- evaluated before the assignments are performed. The order of evaluation is not specified
        -- but we try to match what PUC-Lua does: it evaluates the expressions from left to right
        -- and then performs the assignments from right to left.

        -- In a multiple assignment we have to be careful if we end up with an ir.Value that refers
        -- to a local variable because that variable can potentially be overwritten in another part
        -- of the the assignment.  When that happens we need to save the value to a temporary
        -- variable before resolving the assignments.
        local function save_if_necessary(exp, i)
            local val = self:exp_to_value(bb, exp)
            if  val._tag == "ir.Value.LocalVar" then
                for j = i+1, #vars do
                    local var = vars[j]
                    if  var._tag == "ast.Var.Name" and
                        var._def._tag == "typechecker.Def.Variable" and
                        self.loc_id_of_decl[var._def.decl] == val.id
                    then
                        local v = ir.add_local(self.func, false, exp._type)
                        bb:append_cmd(ir.Cmd.Move(loc, v, val))
                        return ir.Value.LocalVar(v)
                    end
                end
            end
            return val
        end

        local lhss = {}
        for i, var in ipairs(vars) do
            if     var._tag == "ast.Var.Name" then
                assert(var._def._tag == "typechecker.Def.Variable")
                local var_info = self:resolve_variable(var._def.decl)
                if var_info._tag == "to_ir.Var.LocalVar" then
                    table.insert(lhss, to_ir.LHS.Local(var_info.id))
                else
                    tagged_union.error(var_info._tag)
                end

            elseif var._tag == "ast.Var.Bracket" then
                local typ = stat.exps[i]._type
                local t = save_if_necessary(var.t, i)
                local k = save_if_necessary(var.k, i)
                table.insert(lhss, to_ir.LHS.Array(typ, t, k))

            elseif var._tag == "ast.Var.Dot" then
                local t = save_if_necessary(var.exp, i)
                local ttag = var.exp._type._tag
                if     ttag == "types.T.Table" then
                    local typ = stat.exps[i]._type
                    table.insert(lhss, to_ir.LHS.Table(typ, t, var.name))
                elseif ttag == "types.T.Record" then
                    local typ = var.exp._type
                    table.insert(lhss, to_ir.LHS.Record(typ, t, var.name))
                elseif tagged_union.tag_is_type(ttag) then
                    -- Not indexable
                    assert(false)
                else
                    tagged_union.error(ttag)
                end

            else
                tagged_union.error(var._tag)
            end
        end

        -- We'd like to avoid storing the RHS results in temporary variables when possible, to avoid
        -- cluttering the generated code with too many variables. There are three main cases:
        --
        --  1) If the expression is the rightmost one in the RHS then we are free to use
        --  exp_to_assignment because this is also the first assignment to be resolved.
        --  This is always the case for a single assignment.
        --
        -- The other cases are for expressions that are not the rightmost one in the RHS.
        --
        --  2) If the exp is something simple that can be evaluated with exp_to_value then the thing
        --  that we need to worry about is if we are reading from a local variable that is being
        --  assigned in another part of this multi-assignment. We can take care of this with
        --  save_if_necessary.
        --
        --  3) If the expression is something more complex that expects to be evaluated with
        --  exp_to_assignment then in theory we could use exp_to_assignment if we could prove that
        --  it is safe to write to the destination variables at this point in the program, before
        --  the rest of the RHS has been evaluated. However, we don't bother optimizing this last
        --  case because if the programmer has written a complicated multiple-assignment then it is
        --  likely that it isn't something that could have been written as a sequence of single
        --  assignments. Our implementation always ends up creating a temporary variable in this
        --  case because save_if_necessary calls exp_to_value.
        local vals = {}
        for i, exp in ipairs(exps) do
            if i <= #vars then
                local is_extraret = (exp._tag == "ast.Exp.ExtraRet")
                local is_mulfun   = (exp._tag == "ast.Exp.CallFunc" and
                                     exp[i+1] and exp[i+1]._tag == "ast.Exp.ExtraRet")
                local is_last = (i == #vars) or is_mulfun or is_extraret
                if is_last and lhss[i] and lhss[i]._tag == "to_ir.LHS.Local" then
                    self:exp_to_assignment(bb, lhss[i].id, exp)
                    vals[i] = false
                else
                    vals[i] = save_if_necessary(exp, i)
                end
            else
                vals[i] = self:exp_to_value(bb, exp)
            end
        end

        for i = #vars, 1, -1 do
            local lhs = lhss[i]
            local val = vals[i]
            if val then
                local ltag = lhs._tag
                if     ltag == "to_ir.LHS.Local" then
                    bb:append_cmd(ir.Cmd.Move(loc, lhs.id, val))
                elseif ltag == "to_ir.LHS.Array" then
                    bb:append_cmd(ir.Cmd.SetArr(loc, lhs.typ, lhs.arr, lhs.i, val))
                elseif ltag == "to_ir.LHS.Table" then
                    local str = ir.Value.String(lhs.field)
                    bb:append_cmd(ir.Cmd.SetTable(loc, lhs.typ, lhs.t, str, val))
                elseif ltag == "to_ir.LHS.Record" then
                    bb:append_cmd(ir.Cmd.SetField(loc, lhs.typ, lhs.rec, lhs.field, val))
                else
                    tagged_union.error(ltag)
                end
            end
        end

    elseif tag == "ast.Stat.Decl" then
        for _, decl in ipairs(stat.decls) do
            local typ = decl._type
            self.loc_id_of_decl[decl] = ir.add_local(self.func, decl.name, typ)
        end

        for i, exp in ipairs(stat.exps) do
            local decl = stat.decls[i]
            if decl then
                self:exp_to_assignment(bb, self.loc_id_of_decl[decl], exp)
            else
                -- Extra argument to RHS; compute it for side effects and discard result
                local _ = self:exp_to_value(bb, exp)
            end
        end

    elseif tag == "ast.Stat.Call" then
        self:exp_to_assignment(bb, false, stat.call_exp)

    elseif tag == "ast.Stat.Return" then
        local vals = {}
        for i, exp in ipairs(stat.exps) do
            vals[i] = self:exp_to_value(bb, exp)
        end
        self:insert_return(bb, stat.loc, vals)

    elseif tag == "ast.Stat.Break" then
        local id = bb:last_block_id()
        bb:finish_block()
        -- Each loop has a corresponding list of block indices that use a break statement. The
        -- different lists are kept on a stack that follows the nesting of the loops. After the
        -- generation of the blocks for a certain loop, we traverse the corresponding loop's list
        -- and set the right target for the blocks.
        assert(#bb.break_stack > 0)
        local top_break_list = bb.break_stack[#bb.break_stack]
        table.insert(top_break_list, id)

    elseif tag == "ast.Stat.Functions" then

        -- To handle LetRecs (`local f1, f2;`), we register all the locals first.
        for _, func in ipairs(stat.funcs) do
            local loc_id = ir.add_local(self.func, func.name, func._type)
            self.loc_id_of_decl[func] = loc_id

            local exp = func.value
            if not self.fun_id_of_exp[exp] then
                self:register_lambda(exp, func.name)
            end

            local f_id = self.fun_id_of_exp[exp]
            if func.module then
                assert(#self.func_stack == 1)
                self.loc_id_of_exported_func[f_id] = loc_id
            end
        end

        for _ , func in ipairs(stat.funcs) do
            local exp = func.value
            self:convert_func(exp)

            local dst  = self.loc_id_of_decl[func]
            local f_id = self.fun_id_of_exp[exp]
            bb:append_cmd(ir.Cmd.NewClosure(exp.loc, dst, f_id))
        end

        -- To support mutual recursion, upvalues are initialized *after* the closures
        -- have been created.
        for _, func in ipairs(stat.funcs) do
            local f_id = self.fun_id_of_exp[func.value]
            local ir_func = self.module.functions[f_id]
            local captured_vars = self.captured_vals_of_func[ir_func]
            if #captured_vars >= 1 then
                local f_var = self.loc_id_of_decl[func]
                local src_f = ir.Value.LocalVar(f_var)

                local srcs = {}
                for _, val in ipairs(captured_vars) do
                    table.insert(srcs, val)
                end
                bb:append_cmd(ir.Cmd.InitUpvalues(func.loc, src_f, srcs, f_id))
            end
        end

    else
        tagged_union.error(tag)
    end
end

function ToIR:convert_func(lambda)
    local block_builder = self:enter_function(self.fun_id_of_exp[lambda])
    for _, decl in ipairs(lambda.arg_decls) do
      self.loc_id_of_decl[decl] = ir.add_local(self.func, decl.name, decl._type)
    end
    ir.add_ret_vars(self.func)
    self:convert_stat(block_builder, lambda.body)
    self:exit_function(block_builder)
end


local unops = {
    { "#",   "Array",   "ArrLen"  },
    { "#",   "String",  "StrLen"  },
    { "-",   "Integer", "IntNeg"  },
    { "-",   "Float",   "FltNeg"  },
    { "~",   "Integer", "BitNeg"  },
    { "not", "Boolean", "BoolNot" },
}

local binops = {
    { "+"  , "Integer", "Integer", "IntAdd"  },
    { "-"  , "Integer", "Integer", "IntSub"  },
    { "*"  , "Integer", "Integer", "IntMul"  },
    { "//" , "Integer", "Integer", "IntDivi" },
    { "%"  , "Integer", "Integer", "IntMod"  },

    { "+"  , "Float",   "Float",   "FltAdd"  },
    { "-"  , "Float",   "Float",   "FltSub"  },
    { "*"  , "Float",   "Float",   "FltMul"  },
    { "//" , "Float",   "Float",   "FltDivi" },
    { "%"  , "Float",   "Float",   "FltMod"  },
    { "/"  , "Float",   "Float",   "FltDiv"  },

    { "&" , "Integer", "Integer", "BitAnd"    },
    { "|" , "Integer", "Integer", "BitOr"     },
    { "~" , "Integer", "Integer", "BitXor"    },
    { "<<", "Integer", "Integer", "BitLShift" },
    { ">>", "Integer", "Integer", "BitRShift" },

    { "^" , "Float",   "Float",   "FltPow" },

    { "==", "Any",   "Any",   "AnyEq"  },
    { "~=", "Any",   "Any",   "AnyNeq" },

    { "==", "Nil",     "Nil",     "NilEq"  },
    { "~=", "Nil",     "Nil",     "NilNeq" },

    { "==", "Boolean", "Boolean", "BoolEq"  },
    { "~=", "Boolean", "Boolean", "BoolNeq" },

    { "==", "Integer", "Integer", "IntEq"  },
    { "~=", "Integer", "Integer", "IntNeq" },
    { "<" , "Integer", "Integer", "IntLt"  },
    { ">" , "Integer", "Integer", "IntGt"  },
    { "<=", "Integer", "Integer", "IntLeq" },
    { ">=", "Integer", "Integer", "IntGeq" },

    { "==", "Float",   "Float",   "FltEq"  },
    { "~=", "Float",   "Float",   "FltNeq" },
    { "<" , "Float",   "Float",   "FltLt"  },
    { ">" , "Float",   "Float",   "FltGt"  },
    { "<=", "Float",   "Float",   "FltLeq" },
    { ">=", "Float",   "Float",   "FltGeq" },

    { "==", "String",  "String",   "StrEq"  },
    { "~=", "String",  "String",   "StrNeq" },
    { "<" , "String",  "String",   "StrLt"  },
    { ">" , "String",  "String",   "StrGt"  },
    { "<=", "String",  "String",   "StrLeq" },
    { ">=", "String",  "String",   "StrGeq" },

    { "==", "Function","Function", "FunctionEq"  },
    { "~=", "Function","Function", "FunctionNeq" },

    { "==", "Array",   "Array",    "ArrayEq"    },
    { "~=", "Array",   "Array",    "ArrayNeq"    },

    { "==", "Table",   "Table",    "TableEq"    },
    { "~=", "Table",   "Table",    "TableNeq"    },

    { "==", "Record",  "Record",   "RecordEq",  },
    { "~=", "Record",  "Record",   "RecordNeq",  },
}

local function type_specific_unop(op, typ)
   for _, x in ipairs(unops) do
        local op_, typ_, name = x[1], x[2], x[3]
        if
            op == op_ and
            typ._tag == ("types.T." .. typ_)
        then
            return name
        end
    end
    error("impossible")
end

local function type_specific_binop(op, typ1, typ2)
    for _, x in ipairs(binops) do
        local op_, typ1_, typ2_, name = x[1], x[2], x[3], x[4]
        if
            op == op_ and
            typ1._tag == ("types.T." .. typ1_) and
            typ2._tag == ("types.T." .. typ2_)
        then
            return name
        end
    end
    error("impossible")
end

-- Converts a typechecked ast.Exp to a ir.Value. If necessary, will create a fresh variable, and add
-- intermediate computations to the cmds list.
function ToIR:exp_to_value(bb, exp, is_recursive)
    local tag = exp._tag
    if     tag == "ast.Exp.Nil" then
        return ir.Value.Nil

    elseif tag == "ast.Exp.Bool" then
        return ir.Value.Bool(exp.value)

    elseif tag == "ast.Exp.Integer" then
        return ir.Value.Integer(exp.value)

    elseif tag == "ast.Exp.Float" then
        return ir.Value.Float(exp.value)

    elseif tag == "ast.Exp.String" then
        return ir.Value.String(exp.value)

    elseif tag == "ast.Exp.Var" then
        local var = exp.var
        if     var._tag == "ast.Var.Name" then
            local def = var._def

            local decl
            if def._tag == "typechecker.Def.Variable" then
                decl = def.decl
            elseif def._tag == "typechecker.Def.Function" then
                decl = def.func
            elseif def._tag == "typechecker.Def.Builtin" then
                local bname  = def.id
                if     bname == "math.pi"   then return ir.Value.Float(math.pi)
                elseif bname == "math.huge" then return ir.Value.Float(math.huge)
                elseif bname == "math.maxinteger" then return ir.Value.Integer(math.maxinteger)
                elseif bname == "math.mininteger" then return ir.Value.Integer(math.mininteger)
                else
                    -- See https://github.com/pallene-lang/pallene/issues/337
                    error("not implemented")
                end
            else
                tagged_union.error(def._tag)
            end

            local var_info = self:resolve_variable(decl)
            if var_info._tag == "to_ir.Var.LocalVar" then
                return ir.Value.LocalVar(var_info.id)
            elseif var_info._tag == "to_ir.Var.Upvalue" then
                return ir.Value.Upvalue(var_info.id)
            elseif var_info._tag == "to_ir.Var.GlobalVar" then
                -- Fallthrough to default
            else
                tagged_union.error(var_info._tag)
            end

        else
            -- Fallthrough to default
        end

    elseif tag == "ast.Exp.Paren" then
        return self:exp_to_value(bb, exp.exp)
    end

    if is_recursive then
        -- Avoid infinite loop due to type error
        error(string.format(
            "Neither exp_to_value or exp_to_assignment handled tag %q)",
            exp._tag))
    end

    -- Otherwise we need to create a temporary variable
    local v = ir.add_local(self.func, false, exp._type)
    self:exp_to_assignment(bb, v, exp)
    return ir.Value.LocalVar(v)
end

-- Converts the assignment `dst = exp` into a list of ir.Cmd, which are added to the cmds list.
-- If this is a function call, then dst may be false
function ToIR:exp_to_assignment(bb, dst, exp)
    local loc = exp.loc
    local tag = exp._tag

    local use_exp_to_value = false

    if not dst then
        assert(tag == "ast.Exp.CallFunc")
    end

    if     tag == "ast.Exp.InitList" then
        local typ = exp._type
        if     typ._tag == "types.T.Array" then
            local n = ir.Value.Integer(#exp.fields)
            bb:append_cmd(ir.Cmd.NewArr(loc, dst, n))
            bb:append_cmd(ir.Cmd.CheckGC)
            for i, field in ipairs(exp.fields) do
                assert(field._tag == "ast.Field.List")
                local av = ir.Value.LocalVar(dst)
                local iv = ir.Value.Integer(i)
                local vv = self:exp_to_value(bb, field.exp)
                local src_typ = field.exp._type
                bb:append_cmd(ir.Cmd.SetArr(loc, src_typ, av, iv, vv))
            end

        elseif typ._tag == "types.T.Table" then
            local n = ir.Value.Integer(#exp.fields)
            bb:append_cmd(ir.Cmd.NewTable(loc, dst, n))
            bb:append_cmd(ir.Cmd.CheckGC)
            for _, field in ipairs(exp.fields) do
                assert(field._tag == "ast.Field.Rec")
                local tv = ir.Value.LocalVar(dst)
                local kv = ir.Value.String(field.name)
                local vv = self:exp_to_value(bb, field.exp)
                local src_typ = field.exp._type
                local cmd = ir.Cmd.SetTable(loc, src_typ, tv, kv, vv)
                bb:append_cmd(cmd)
            end

        elseif typ._tag == "types.T.Record" then
            local field_exps = {}
            for _, field in ipairs(exp.fields) do
                field_exps[field.name] = field.exp
            end

            bb:append_cmd(ir.Cmd.NewRecord(loc, typ, dst))
            bb:append_cmd(ir.Cmd.CheckGC)
            for _, field_name in ipairs(typ.field_names) do
                local f_exp = assert(field_exps[field_name])
                local dv = ir.Value.LocalVar(dst)
                local vv = self:exp_to_value(bb, f_exp)
                bb:append_cmd(ir.Cmd.SetField(exp.loc, typ, dv, field_name, vv))
            end
        elseif typ._tag == "types.T.Module" then
            -- Fallthrough to default

        else
            tagged_union.error(typ._tag)
        end

    elseif tag == "ast.Exp.UpvalueRecord" then
        local typ = exp._type
        assert(typ._tag == "types.T.Record")
        -- UpvalueRecords are only used initialize local variables that are mutably captured, and lack
        -- an initializer upon declaration.
        assert(typ.is_upvalue_box)

        bb:append_cmd(ir.Cmd.NewRecord(loc, typ, dst))
        bb:append_cmd(ir.Cmd.CheckGC)

    elseif tag == "ast.Exp.Lambda" then
        local f_id = self:register_lambda(exp, "$lambda")
        self:convert_func(exp)

        bb:append_cmd(ir.Cmd.NewClosure(exp.loc, dst, f_id))
        local func = self.module.functions[f_id]
        local captured_vars = self.captured_vals_of_func[func]
        if #captured_vars >= 1 then
            local src_f = ir.Value.LocalVar(dst)
            local srcs = {}
            for _, upval in ipairs(captured_vars) do
                table.insert(srcs, upval)
            end
            bb:append_cmd(ir.Cmd.InitUpvalues(exp.loc, src_f, srcs, f_id))
        end

    elseif tag == "ast.Exp.ExtraRet" then
        assert(self.dsts_of_call[exp.call_exp])
        self.dsts_of_call[exp.call_exp][exp.i] = dst

    elseif tag == "ast.Exp.CallFunc" then

        local f_typ = exp.exp._type
        local def = (
            exp.exp._tag == "ast.Exp.Var" and
            exp.exp.var._tag == "ast.Var.Name" and
            exp.exp.var._def )

        -- Prepare the list of destination variables.
        -- If this is a function with multiple return values then dsts[2]..dsts[N] will be
        -- initialized later, by ExtraRet.
        assert(not self.dsts_of_call[exp])
        local dsts = {}
        for i = 1, #exp._types do
            dsts[i] = false
        end
        if dst then
            dsts[1] = dst
        end
        table.insert(self.call_exps, exp)
        self.dsts_of_call[exp] = dsts

        -- Evaluate the function call expression
        local f_val
        if  def and def._tag == "typechecker.Def.Builtin" then
            f_val = false
        else
            f_val = self:exp_to_value(bb, exp.exp)
        end

        local function evaluate_args(nargs)
            local xs = {}
            for i = 1, nargs do
                xs[i] = self:exp_to_value(bb, exp.args[i])
            end
            return xs
        end

        -- Generate the function call command
        if     def and def._tag == "typechecker.Def.Builtin" then
            local xs = evaluate_args(#exp.args)

            local bname = def.id
            if     bname == "io.write" then
                assert(#xs == 1)
                bb:append_cmd(ir.Cmd.BuiltinIoWrite(loc, xs))
            elseif bname == "math.abs" then
                assert(#xs == 1)
                bb:append_cmd(ir.Cmd.BuiltinMathAbs(loc, dsts, xs))
            elseif bname == "math.ceil" then
                assert(#xs == 1)
                bb:append_cmd(ir.Cmd.BuiltinMathCeil(loc, dsts, xs))
            elseif bname == "math.floor" then
                assert(#xs == 1)
                bb:append_cmd(ir.Cmd.BuiltinMathFloor(loc, dsts, xs))
            elseif bname == "math.fmod" then
                assert(#xs == 2)
                bb:append_cmd(ir.Cmd.BuiltinMathFmod(loc, dsts, xs))
            elseif bname == "math.exp" then
                assert(#xs == 1)
                bb:append_cmd(ir.Cmd.BuiltinMathExp(loc, dsts, xs))
            elseif bname == "math.log" then
                assert(#xs == 2)
                bb:append_cmd(ir.Cmd.BuiltinMathLog(loc, dsts, xs))
            elseif bname == "math.modf" then
                assert(#xs == 1)
                bb:append_cmd(ir.Cmd.BuiltinMathModf(loc, dsts, xs))
            elseif bname == "math.pow" then
                assert(#xs == 2)
                bb:append_cmd(ir.Cmd.BuiltinMathPow(loc, dsts, xs))
            elseif bname == "math.sqrt" then
                assert(#xs == 1)
                bb:append_cmd(ir.Cmd.BuiltinMathSqrt(loc, dsts, xs))
            elseif bname == "string.char" then
                assert(#xs == 1)
                bb:append_cmd(ir.Cmd.BuiltinStringChar(loc, dsts, xs))
                bb:append_cmd(ir.Cmd.CheckGC)
            elseif bname == "string.sub" then
                assert(#xs == 3)
                bb:append_cmd(ir.Cmd.BuiltinStringSub(loc, dsts, xs))
                bb:append_cmd(ir.Cmd.CheckGC)
            elseif bname == "type" then
                assert(#xs == 1)
                bb:append_cmd(ir.Cmd.BuiltinType(loc, dsts, xs))
            elseif bname == "tostring" then
                assert(#xs == 1)
                bb:append_cmd(ir.Cmd.BuiltinTostring(loc, dsts, xs))
            else
                tagged_union.error(bname)
            end

        elseif def and def._tag == "typechecker.Def.Function" then
            -- CallStatic is used to call toplevel functions, which are always referenced
            -- as upvalues or local variables.
            assert(f_val._tag == "ir.Value.Upvalue" or f_val._tag == "ir.Value.LocalVar")
            local xs = evaluate_args(#exp.args)
            bb:append_cmd(ir.Cmd.CallStatic(loc, f_typ, dsts, f_val, xs))
        else
            local xs = evaluate_args(exp._original_nargs)
            bb:append_cmd(ir.Cmd.CallDyn(loc, f_typ, dsts, f_val, xs))
        end

    elseif tag == "ast.Exp.Var" then
        local var = exp.var
        if     var._tag == "ast.Var.Name" then
            local def = var._def
            if def._tag == "typechecker.Def.Variable" then
                local var_info = self:resolve_variable(def.decl)

                if var_info._tag == "to_ir.Var.LocalVar" or var_info._tag == "to_ir.Var.Upvalue" then
                    use_exp_to_value = true
                elseif var_info._tag == "to_ir.Var.GlobalVar" then
                    bb:append_cmd(ir.Cmd.GetGlobal(loc, dst, var_info.id))
                else
                    tagged_union.error(var_info._tag)
                end
            else
                use_exp_to_value = true
            end

        elseif var._tag == "ast.Var.Bracket" then
            local arr = self:exp_to_value(bb, var.t)
            local i   = self:exp_to_value(bb, var.k)
            local dst_typ = var._type
            bb:append_cmd(ir.Cmd.GetArr(loc, dst_typ, dst, arr, i))

        elseif var._tag == "ast.Var.Dot" then
              local typ = assert(var.exp._type)
              local field = var.name
              local cmd
              local rec = self:exp_to_value(bb, var.exp)
              if     typ._tag == "types.T.Table" then
                  local key = ir.Value.String(field)
                  local dst_typ = typ.fields[field]
                  cmd = ir.Cmd.GetTable(loc, dst_typ, dst, rec, key)
              elseif typ._tag == "types.T.Record" then
                  cmd = ir.Cmd.GetField(loc, typ, dst, rec, field)
              else
                  tagged_union.error(typ._tag)
              end

              bb:append_cmd(cmd)

        else
            tagged_union.error(var._tag)
        end

    elseif tag == "ast.Exp.Unop" then
        local op = exp.op
        if op == "not" then
            local e = self:exp_to_value(bb, exp.exp)
            local v = self:value_is_truthy(bb, exp.exp, e)
            bb:append_cmd(ir.Cmd.Unop(loc, dst, "BoolNot", v))
        else
            local irop = type_specific_unop(op, exp.exp._type)
            local v = self:exp_to_value(bb, exp.exp)
            bb:append_cmd(ir.Cmd.Unop(loc, dst, irop, v))
        end

    elseif tag == "ast.Exp.Concat" then
        local xs = {}
        for i, x_exp in ipairs(exp.exps) do
            xs[i] = self:exp_to_value(bb, x_exp)
        end
        bb:append_cmd(ir.Cmd.Concat(loc, dst, xs))
        bb:append_cmd(ir.Cmd.CheckGC)

    elseif tag == "ast.Exp.Binop" then
        local op = exp.op
        if op == "and" then
            self:exp_to_assignment(bb, dst, exp.lhs)
            local v = ir.Value.LocalVar(dst)
            local cond_bool = self:value_is_truthy(bb, exp.lhs, v)
            local if_begin_jmpIf = bb:append_cmd(ir.Cmd.JmpIf(loc, cond_bool, nil, nil))
            local then_begin = bb:finish_block()
            self:exp_to_assignment(bb, dst, exp.rhs)
            local if_end = bb:finish_block()
            if_begin_jmpIf.target_true  = then_begin
            if_begin_jmpIf.target_false = if_end

            elseif op == "or" then
                self:exp_to_assignment(bb, dst, exp.lhs)
                local v = ir.Value.LocalVar(dst)
                local cond_bool = self:value_is_truthy(bb, exp.lhs, v)
                local if_begin_jmpIf = bb:append_cmd(ir.Cmd.JmpIf(loc, cond_bool, nil, nil))
                local begin_else = bb:finish_block()
                self:exp_to_assignment(bb, dst, exp.rhs)
                local if_end = bb:finish_block()
                if_begin_jmpIf.target_true  = if_end
                if_begin_jmpIf.target_false = begin_else

        elseif op == ".." then
            -- Flatten (a .. (b .. (c .. d))) into (a .. b .. c .. d)
            local xs = {}
            while exp._tag == "ast.Exp.Binop" and exp.op == ".." do
                table.insert(xs, self:exp_to_value(bb, exp.lhs))
                exp = exp.rhs
            end
            table.insert(xs, self:exp_to_value(bb, exp))

            bb:append_cmd(ir.Cmd.Concat(loc, dst, xs))

        else
            local irop = type_specific_binop(op, exp.lhs._type, exp.rhs._type)
            local v1 = self:exp_to_value(bb, exp.lhs)
            local v2 = self:exp_to_value(bb, exp.rhs)
            bb:append_cmd(ir.Cmd.Binop(loc, dst, irop, v1, v2))
        end

    elseif tag == "ast.Exp.Cast" then
        local dst_typ = exp._type
        local src_typ = exp.exp._type
        if src_typ._tag == dst_typ._tag then
            -- Do-nothing cast
            self:exp_to_assignment(bb, dst, exp.exp)
        else
            local v = self:exp_to_value(bb, exp.exp)
            if     dst_typ._tag == "types.T.Any" then
                bb:append_cmd(ir.Cmd.ToDyn(loc, src_typ, dst, v))
            elseif src_typ._tag == "types.T.Any" then
                bb:append_cmd(ir.Cmd.FromDyn(loc, dst_typ, dst, v))
            else
                error(string.format("error casting from type '%s' to '%s'",
                        types.tostring(src_typ), types.tostring(dst_typ)))
            end
        end

    elseif tag == "ast.Exp.ToFloat" then
        local v = self:exp_to_value(bb, exp.exp)
        bb:append_cmd(ir.Cmd.ToFloat(loc, dst, v))

    else
        use_exp_to_value = true
    end

    if use_exp_to_value then
        local value = self:exp_to_value(bb, exp, true)
        bb:append_cmd(ir.Cmd.Move(loc, dst, value))
    end
end

-- Returns a boolean value corresponding to whether exp is truthy.
-- As usual, may add intermediate cmds to the cmds list
function ToIR:value_is_truthy(bb, exp, val)
    local typ = exp._type
    if typ._tag == "types.T.Boolean" then
        return val
    elseif typ._tag == "types.T.Any" then
        local b = ir.add_local(self.func, false, types.T.Boolean)
        bb:append_cmd(ir.Cmd.IsTruthy(exp.loc, b, val))
        return ir.Value.LocalVar(b)
    elseif tagged_union.tag_is_type(typ) then
        -- Cannot be tested for truthyness
        assert(false)
    else
        tagged_union.error(typ._tag)
    end
end

function ToIR:new_local_from_decl(decl)
    local v = ir.add_local(self.func, decl.name, decl._type)
    self.loc_id_of_decl[decl] = v
    return v
end

return to_ir
