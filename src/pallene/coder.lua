-- Copyright (c) 2020, The Pallene Developers
-- Pallene is licensed under the MIT license.
-- Please refer to the LICENSE and AUTHORS files for details
-- SPDX-License-Identifier: MIT

-- COMPILING PALLENE IR DOWN TO C
-- ==============================
-- This compiler pass converts a Pallene IR module into to executable C code.
-- This file is fairly long. For navigation, look for the sectioning comments.

local coder = {}

local C = require "pallene.C"
local gc = require "pallene.gc"
local ir = require "pallene.ir"
local pallenelib = require "pallene.pallenelib"
local types = require "pallene.types"
local util = require "pallene.util"

local tagged_union = require "pallene.tagged_union"
local define_union = tagged_union.in_namespace(coder, "coder")

local Coder
local RecordCoder

function coder.generate(module, modname, pallene_filename, flags)
    local c = Coder.new(module, modname, pallene_filename, flags)
    local code = c:generate_module_header() .. c:generate_module_body()
    return code, {}
end

--
-- #C-variables
--

-- @param typ : types.T
-- @returns the correspoinding C type, as a string.
local function ctype(typ)
    local tag = typ._tag
    if     tag == "types.T.Nil"      then return "int"
    elseif tag == "types.T.Boolean"  then return "char"
    elseif tag == "types.T.Integer"  then return "lua_Integer"
    elseif tag == "types.T.Float"    then return "lua_Number"
    elseif tag == "types.T.String"   then return "TString *"
    elseif tag == "types.T.Function" then return "TValue"
    elseif tag == "types.T.Array"    then return "Table *"
    elseif tag == "types.T.Table"    then return "Table *"
    elseif tag == "types.T.Record"   then return "Udata *"
    elseif tag == "types.T.Any"      then return "TValue"
    else
        tagged_union.error(typ)
    end
end

--
--
--

Coder = util.Class()
function Coder:init(module, modname, filename, flags)
    self.module = module
    self.modname = modname
    self.filename = filename
    self.flags = flags

    self.current_func = false

    self.constants = {} -- { coder.Constant }
    self.k_slot_of_metatable = {} -- typ  => integer
    self.k_slot_of_string    = {} -- str  => integer
    self:init_upvalues()

    self.record_ids    = {}      -- types.T.Record => integer
    self.record_coders = {}      -- types.T.Record => RecordCoder
    for i, typ in ipairs(self.module.record_types) do
        self.record_ids[typ] = i
        self.record_coders[typ] = RecordCoder.new(self, typ)
    end

    self.gc = {} -- (see gc.compute_stack_slots)
    self.max_lua_call_stack_usage = {} -- func => integer
    self:init_gc()
end

--
-- #slots
--

-- @param src_slot: The TValue* to read from
local function lua_value(typ, src_slot)
    local tmpl
    local tag = typ._tag
    if     tag == "types.T.Nil"      then tmpl = "0"
    elseif tag == "types.T.Boolean"  then tmpl = "pallene_bvalue($src)"
    elseif tag == "types.T.Integer"  then tmpl = "ivalue($src)"
    elseif tag == "types.T.Float"    then tmpl = "fltvalue($src)"
    elseif tag == "types.T.String"   then tmpl = "tsvalue($src)"
    elseif tag == "types.T.Function" then tmpl = "*($src)"
    elseif tag == "types.T.Array"    then tmpl = "hvalue($src)"
    elseif tag == "types.T.Table"    then tmpl = "hvalue($src)"
    elseif tag == "types.T.Record"   then tmpl = "uvalue($src)"
    elseif tag == "types.T.Any"      then tmpl = "*($src)"
    else tagged_union.error(tag)
    end

    local res = util.render(tmpl, {src = src_slot})
    -- Clean up *(&x)
    return string.match(res, "^%*%(%&(.*)%)$") or res
end

local function unchecked_get_slot(typ, dst, src)
    return (util.render([[ $dst = $value; ]], {
        dst = dst,
        value = lua_value(typ, src)
    }))
end

-- Set a TValue* slot that is in the Lua or C stack.
-- @param typ: type of source value
local function set_stack_slot(typ, dst_slot, value)
    local tmpl
    local tag = typ._tag
    if     tag == "types.T.Nil"      then tmpl = "setnilvalue($dst);"
    elseif tag == "types.T.Boolean"  then tmpl = "pallene_setbvalue($dst, $src);"
    elseif tag == "types.T.Integer"  then tmpl = "setivalue($dst, $src);"
    elseif tag == "types.T.Float"    then tmpl = "setfltvalue($dst, $src);"
    elseif tag == "types.T.String"   then tmpl = "setsvalue(L, $dst, $src);"
    elseif tag == "types.T.Function" then tmpl = "setobj(L, $dst, &$src);"
    elseif tag == "types.T.Array"    then tmpl = "sethvalue(L, $dst, $src);"
    elseif tag == "types.T.Table"    then tmpl = "sethvalue(L, $dst, $src);"
    elseif tag == "types.T.Record"   then tmpl = "setuvalue(L, $dst, $src);"
    elseif tag == "types.T.Any"      then tmpl = "setobj(L, $dst, &$src);"
    else tagged_union.error(tag)
    end

    return (util.render(tmpl, { dst = dst_slot, src = value }))
end

local function gc_barrier(typ, value, parent)
    if types.is_gc(typ) then
        local tmpl
        if typ._tag == "types.T.Any" or typ._tag == "types.T.Function" then
            tmpl = "luaC_barrierback(L, obj2gco($p), &$v);"
        else
            tmpl = "pallene_barrierback_unboxed(L, obj2gco($p), obj2gco($v));"
        end
        return util.render(tmpl, { p = parent, v = value })
    else
        return ""
    end
end

-- Set a TValue* slot that belongs to some heap object (array, record, etc).
-- Must receive a pointer to the parent object, due to the GC write barrier.
local function set_heap_slot(typ, dst_slot, value, parent)
    local lines = {}
    table.insert(lines, set_stack_slot(typ, dst_slot, value))
    table.insert(lines, gc_barrier(typ, value, parent))
    return table.concat(lines, "\n")
end

function Coder:push_to_stack(typ, value)
    return (util.render([[
        ${set_stack_slot}
        L->top.p++;
    ]],{
        set_stack_slot = set_stack_slot(typ, "s2v(L->top.p)", value),
    }))
end

--
-- #tags
--

local function pallene_type_tag(typ)
    local tag = typ._tag
    if     tag == "types.T.Nil"      then return "nil"
    elseif tag == "types.T.Boolean"  then return "boolean"
    elseif tag == "types.T.Integer"  then return "integer"
    elseif tag == "types.T.Float"    then return "float"
    elseif tag == "types.T.String"   then return "string"
    elseif tag == "types.T.Function" then return "function"
    elseif tag == "types.T.Array"    then return "table"
    elseif tag == "types.T.Table"    then return "table"
    elseif tag == "types.T.Record"   then return typ.name
    elseif tag == "types.T.Any"      then assert(false) -- 'Any' is not a type tag
    else tagged_union.error(tag)
    end
end

function Coder:test_tag(typ, slot)
    local tmpl
    local tag = typ._tag
    if     tag == "types.T.Nil"      then tmpl = "ttisnil($slot)"
    elseif tag == "types.T.Boolean"  then tmpl = "ttisboolean($slot)"
    elseif tag == "types.T.Integer"  then tmpl = "ttisinteger($slot)"
    elseif tag == "types.T.Float"    then tmpl = "ttisfloat($slot)"
    elseif tag == "types.T.String"   then tmpl = "ttisstring($slot)"
    elseif tag == "types.T.Function" then tmpl = "ttisfunction($slot)"
    elseif tag == "types.T.Array"    then tmpl = "ttistable($slot)"
    elseif tag == "types.T.Table"    then tmpl = "ttistable($slot)"
    elseif tag == "types.T.Any"    then tmpl = "1"
    elseif tag == "types.T.Record"   then
        assert(not typ.is_upvalue_box)
        return (util.render([[pallene_is_record($slot, $mt_slot)]], {
            slot = slot,
            mt_slot = self:metatable_upvalue_slot(typ),
        }))
    end
    return (util.render(tmpl, {slot = slot}))
end

-- Raise an error if the given table contains a metatable. Pallene would rather raise an error in
-- these cases instead of invoking the metatable operations, which may impair program optimization
-- even if they are never called.
local function check_no_metatable(self, src, loc)
    local setline = ""
    if self.flags.use_traceback then
        setline = string.format("PALLENE_SETLINE(%d);", loc.line)
    end

    return (util.render([[
        if ($src->metatable) {
            ${setline}
            pallene_runtime_array_metatable_error(L, PALLENE_SOURCE_FILE, $line);
        }
    ]], {
        src = src,
        setline = setline,
        line = C.integer(loc.line),
    }))
end

-- Convert a Lua value to a Pallene value, performing a tag check. Make sure to use the appropriate
-- function depending on whether this Lua value is coming from the Lua stack or a Lua table.
--
-- typ: expected type
-- dst: Pallene output variable
-- src: Lua input variable (TValue*)
-- loc: source code location (for error reporting)
-- description_fmt: Format string in lua_pushfstring format, which
--                  describes what this tag check is for.
--                  Received as a Lua string.
-- ... (extra_args): Parameters to the format string.
--                  Received as serialized C expressions.
--

function Coder:get_stack_slot(typ, dst, slot, loc, description_fmt, ...)

    local check_tag
    if typ._tag == "types.T.Any" then
        check_tag = ""
    else
        assert(not typ.is_upvalue_box)
        local extra_args = table.pack(...)

        local setline = ""
        if self.flags.use_traceback then
            setline = string.format("PALLENE_SETLINE(%d);", loc.line)
        end

        check_tag = util.render([[
            if (l_unlikely(!$test)) {
                ${setline}
                pallene_runtime_tag_check_error(L,
                    $file, $line, $expected_type, $slot,
                    ${description_fmt}${opt_comma}${extra_args});
            }
        ]], {
            test = self:test_tag(typ, slot),
            setline = setline,
            file = C.string(loc and loc.file_name or "<anonymous>"),
            line = C.integer(loc and loc.line or 0),
            expected_type = C.string(pallene_type_tag(typ)),
            slot = slot,
            description_fmt = C.string(description_fmt),
            opt_comma = (#extra_args == 0 and "" or ", "),
            extra_args = table.concat(extra_args, ", "),
        })
    end

    return (util.render([[
        $check_tag
        $get_slot
    ]], {
        check_tag = check_tag,
        get_slot  = unchecked_get_slot(typ, dst, slot)
    }))
end


function Coder:get_luatable_slot(typ, dst, slot, tab, loc, description_fmt, ...)

    local parts = {}

    table.insert(parts,
        self:get_stack_slot(typ, dst, slot, loc, description_fmt, ...))

    -- Lua calls the __index metamethod when it reads from an empty field. We want to avoid that in
    -- Pallene, so we raise an error instead.
    if typ._tag == "types.T.Any" or typ._tag == "types.T.Nil" then
        table.insert(parts, util.render([[
            if (isempty($slot)) {
                ${check_no_metatable}
            }
        ]], {
            slot = slot,
            check_no_metatable = check_no_metatable(self, tab, loc),
        }))
    end

    -- Another tricky thing about holes in Lua 5.4 is that they actually contain "empty", a special kind
    -- of nil. When reading them, they must be converted to regular nils, just like how the "rawget"
    -- function in lapi.c does.
    if typ._tag == "types.T.Any" then
        table.insert(parts, util.render([[
            if (isempty($slot)) {
                setnilvalue(&$dst);
            }
        ]], {
            slot = slot,
            dst = dst,
        }))
    end

    return table.concat(parts, "\n")
end

--
--  # Local variables
--

-- @returns the C variable name for the variable v_id
function Coder:c_var(v_id)
    return "x" .. v_id
end

-- @returns the C parameter name for the upvalue u_id
function Coder:c_upval(u_id)
    assert(self.current_func)
    local typ = self.current_func.captured_vars[u_id].typ
    -- Since upvalue boxes do not have metatables, type checking them at runtime is not possible.
    -- Moreover, since upvalues are only passed around internally by Pallene, it is ok to assume that
    -- their types will be correct. So we directly cast it using `lua_value` without a tag check.
    return lua_value(typ, string.format("&U[%d]", u_id))
end

-- @returns the C return variable name for the variable ret_i
function Coder:c_ret_var(ret_i)
    return "ret" .. ret_i
end

-- @returns the C expression for an ir.Value
function Coder:c_value(value)
    local tag = value._tag
    if     tag == "ir.Value.Nil" then
        return "0"
    elseif tag == "ir.Value.Bool" then
        return C.boolean(value.value)
    elseif tag == "ir.Value.Integer" then
        return C.integer(value.value)
    elseif tag == "ir.Value.Float" then
        return C.float(value.value)
    elseif tag == "ir.Value.String" then
        local str = value.value
        return lua_value(types.T.String(), self:string_upvalue_slot(str))
    elseif tag == "ir.Value.LocalVar" then
        return self:c_var(value.id)
    elseif tag == "ir.Value.Upvalue" then
        return self:c_upval(value.id)
    else
        tagged_union.error(tag)
    end
end

function Coder:c_label(index)
    return "L" .. index
end

-- The information for creating a C local var for a given Pallene local var.
function Coder:prepare_local_var(func, v_id)
    local c_name = self:c_var(v_id)
    local typ    = func.vars[v_id].typ
    local p_name = func.vars[v_id].name
    return typ, c_name, (p_name and " "..C.comment(p_name) or "")
end


--
-- # Pallene entry point
--
-- Pallene functions receive as parameters:
--  - Lua state (L)
--  - Global constants table (K)
--  - Regular parameters (x1, x2, x3...)
--  - Output parameters (ret2, ret3, ret4...)
--
-- If the function returns no results, it returns void.
-- Otherwhise it returns its return value. Multiple returns are not implemented
--
-- It is assumed that the all arguments are saved in the Lua stack by the caller

function Coder:pallene_entry_point_name(f_id)
    return string.format("function_%02d", f_id)
end

function Coder:pallene_entry_point_declaration(f_id)
    local func = self.module.functions[f_id]
    local arg_types = func.typ.arg_types
    local ret_types = func.typ.ret_types

    local ret_type = (#ret_types >= 1 and ctype(ret_types[1]) or "void")

    local args = {} -- { {ctype, name , comment} }
    table.insert(args, {"lua_State *" , "L",    ""})
    table.insert(args, {"Udata * restrict " , "K",  ""}) -- constants table
    table.insert(args, {"TValue * restrict ", "U" , ""}) -- upvalue array

    for i = 1, #arg_types do
        local v_id = ir.arg_var(func, i)
        local typ, c_name, comment = self:prepare_local_var(func, v_id)
        table.insert(args, {ctype(typ), c_name, comment})
    end
    for i = 2, #ret_types do
        local typ  = ret_types[i]
        local name = self:c_ret_var(i)
        table.insert(args, {ctype(typ).."*", name, ""})
    end

    local arg_lines = {}
    for i, arg in ipairs(args) do
        local decl    = C.declaration(arg[1], arg[2])
        local comma   = (i < #args) and "," or " "
        local comment = arg[3]
        table.insert(arg_lines, decl..comma..comment)
    end

    return (util.render([[
        static ${ret_type} ${name}(
            ${args}
        )]], { -- no whitespace after ")"
            ret_type = ret_type,
            name = self:pallene_entry_point_name(f_id),
            args = table.concat(arg_lines, "\n"),
        }))
end

function Coder:pallene_entry_point_definition(f_id)
    local func = self.module.functions[f_id]
    local arg_types = func.typ.arg_types

    self.current_func = func

    local name_comment = func.name
    if func.loc then
        name_comment = name_comment .. " " .. func.loc:show_line()
    end

    local prologue = {}

    local max_frame_size = self.gc[func].max_frame_size
    local slots_needed = max_frame_size + self.max_lua_call_stack_usage[func]

    local setline = ""
    local frameexit = ""
    if self.flags.use_traceback then
        table.insert(prologue, util.render([[
            /**/
            PALLENE_C_FRAMEENTER(L, "$name");
            /**/
        ]], {
            name = func.name
        }));

        setline = string.format("PALLENE_SETLINE(%d);", func.loc and func.loc.line or 0)
        if #func.typ.ret_types == 0 then
            frameexit = "PALLENE_FRAMEEXIT();"
        end
    end

    if slots_needed > 0 then
        table.insert(prologue, util.render([[
            if (!lua_checkstack(L, $n)) {
                ${setline}
                pallene_runtime_cant_grow_stack_error(L);
            }
        ]], {
            n    = C.integer(slots_needed),
            setline = setline,
        }))
    end
    table.insert(prologue, "StackValue *base = L->top.p;");
    table.insert(prologue, self:savestack())
    table.insert(prologue, "/**/")

    for v_id = #arg_types + 1, #func.vars do
        -- To avoid -Wmaybe-uninitialized warnings we have to initialize our local variables of type
        -- "Any". Nils and Booleans only set the type tag of the TValue and leave the "._value"
        -- field uninitialized and the C compiler doesn't like that because it means that a setobj
        -- may read from uninitialized memory.
        local typ, c_name, comment = self:prepare_local_var(func, v_id)
        local decl = C.declaration(ctype(typ), c_name)
        local initializer = (typ._tag == "types.T.Any") and " = {{0},0}" or ""
        table.insert(prologue, decl..initializer..";"..comment)
    end

    local body = self:generate_blocks(func)

    local ret_mult = ""
    local ret = ""
    if #func.ret_vars > 0 then
        -- We assign the dsts from right to left, in order to match Lua's semantics when a
        -- destination variable appears more than once in the LHS. For example, in `x,x = f()`.
        -- For a more in-depth discussion, see the implementation of ast.Stat.Assign in to_ir.lua
        local returns = {}
        for i = #func.ret_vars, 2, -1 do
            local var = self:c_var(func.ret_vars[i])
            table.insert(returns,
                util.render([[ *$reti = $v; ]], { reti = self:c_ret_var(i), v = var }))
        end
        ret_mult = table.concat(returns, "\n")

        local var1 = self:c_var(func.ret_vars[1])
        ret = "return " .. var1 .. ";"
    end

    return (util.render([[
        ${name_comment}
        ${fun_decl} {
            ${prologue}
            /**/
            ${body}
            ${ret_mult}
            ${frameexit}
            ${ret}
        }
    ]], {
        name_comment = C.comment(name_comment),
        fun_decl = self:pallene_entry_point_declaration(f_id),
        prologue = table.concat(prologue, "\n"),
        body = body,
        ret_mult = ret_mult,
        frameexit = frameexit,
        ret = ret,
    }))
end

function Coder:call_pallene_function(dsts, f_id, cclosure, xs)

    local func       = self.module.functions[f_id]
    local n_upvalues = #func.captured_vars

    local args = {}
    table.insert(args, "L")
    table.insert(args, "K")

    -- If the Pallene entry point of the closure being called doesn't have any upvalues,
    -- we can simply pass NULL as it's `upvalues` parameter as it will be unused anyway.
    local upvals
    if n_upvalues >= 1 then
        upvals = cclosure.."->upvalue"
    else
        upvals = "NULL"
    end
    table.insert(args, upvals)

    for _, x in ipairs(xs) do
        table.insert(args, x)
    end
    for i = 2, #dsts do
        table.insert(args, "&"..dsts[i])
    end

    local call = util.render([[$name($args);]], {
        name = self:pallene_entry_point_name(f_id),
        args = table.concat(args, ", "),
    })

    if dsts[1] then
        return dsts[1].." = "..call
    else
        return call
    end
end

--
-- # Lua entry point
--
-- Lua interface to a pallene function. Used when Lua is calling pallene
-- functions, or when Pallene is calling a variable of function type.
--
-- The first upvalue should be the module's global userdata object.

function Coder:lua_entry_point_name(f_id)
    return string.format("function_%02d_lua", f_id)
end

function Coder:lua_entry_point_declaration(f_id)
    return (util.render([[static int ${name}(lua_State *L)]], {
        name = self:lua_entry_point_name(f_id)
    }))
end

function Coder:lua_entry_point_definition(f_id)
    local func = self.module.functions[f_id]
    local fname = func.name
    local arg_types = func.typ.arg_types
    local ret_types = func.typ.ret_types

    self.current_func = func

    -- We unconditionally initialize the `K` userdata here, in case one of the tag checking tests
    -- needs to use it. We don't bother to make this initialization conditional because in the case
    -- that really matters (small leaf functions that don't use `K`) the C compiler can optimize this
    -- read away after inlining the Pallene entry point.
    local init_global_userdata = [[
        CClosure *func = clCvalue(s2v(base));
        Udata *K = uvalue(&func->upvalue[0]);
    ]]

    local frameenter = ""
    local frameexit  = ""
    local nargs = #arg_types
    local cargs = nargs
    if self.flags.use_traceback then
        frameenter = util.render([[
            /**/
            PALLENE_LUA_FRAMEENTER(L, $fun_name);
            /**/
        ]], {
            fun_name = self:lua_entry_point_name(f_id),
        })
        -- It's as simple as popping the finalizer.
        frameexit = "lua_pop(L, 1);"

        -- We will be having our finalizer on top of our stack.
        cargs = cargs + 1
    end

    local arity_check = util.render([[
        int nargs = lua_gettop(L);
        if (l_unlikely(nargs != $cargs)) {
            pallene_runtime_arity_error(L, $fname, $nargs, nargs);
        }
    ]], {
        cargs = C.integer(cargs),
        nargs = C.integer(nargs),
        fname = C.string(fname),
    })

    local arg_vars  = {}
    local arg_decls = {}

    for i, typ in ipairs(arg_types) do
        local name = self:c_var(i)
        table.insert(arg_vars, name)
        table.insert(arg_decls, C.declaration(ctype(typ), name)..";")
    end

    local init_args = {}

    for i, typ in ipairs(arg_types) do
        local name = func.vars[i].name
        local dst = arg_vars[i]
        local src = string.format("s2v(base + %s)", C.integer(i))
        table.insert(init_args,
            self:get_stack_slot(typ, dst, src,
                func.loc, "argument '%s'", C.string(name)))
    end

    local ret_vars  = {}
    local ret_decls = {}
    for i, typ in ipairs(ret_types) do
        local ret = string.format("ret%d", i)
        table.insert(ret_vars, ret)
        table.insert(ret_decls, C.declaration(ctype(typ), ret)..";")
    end

    local call_pallene = self:call_pallene_function(ret_vars, f_id, "func", arg_vars,
        self:lua_entry_point_name(f_id))

    local push_results = {}
    for i, typ in ipairs(ret_types) do
        table.insert(push_results, self:push_to_stack(typ, ret_vars[i]))
    end

    return (util.render([[
        ${fun_decl}
        {
            StackValue *base = L->ci->func.p;
            ${init_global_userdata}
            ${lua_fenter}
            /**/
            ${arity_check}
            /**/
            ${arg_decls}
            /**/
            ${init_args}
            /**/
            ${ret_decls}
            ${call_pallene}
            ${lua_fexit}
            ${push_results}
            return $nresults;
        }
    ]], {
        fun_decl = self:lua_entry_point_declaration(f_id),
        init_global_userdata = init_global_userdata,
        lua_fenter = frameenter,
        arity_check = arity_check,
        arg_decls = table.concat(arg_decls, "\n"),
        init_args = table.concat(init_args, "\n/**/\n"),
        ret_decls = table.concat(ret_decls, "\n"),
        call_pallene = call_pallene,
        push_results = table.concat(push_results, "\n"),
        lua_fexit = frameexit,
        nresults = C.integer(#ret_types)
    }))
end

--
-- # Global coder
--
-- This section of the program is responsible for keeping track of the "global" values in the module
-- that need to be seen from every function. We store them in the uservalues of an userdata object.

define_union("Constant", {
    Metatable = {"typ"},
    String = {"str"},
    DebugUserdata = {},
    DebugMetatable = {},
})

function Coder:init_upvalues()

    -- If we are using tracebacks
    if self.flags.use_traceback then
        table.insert(self.constants, coder.Constant.DebugUserdata())
        table.insert(self.constants, coder.Constant.DebugMetatable())
    end

    -- Metatables
    for _, typ in ipairs(self.module.record_types) do
        if not typ.is_upvalue_box then
            table.insert(self.constants, coder.Constant.Metatable(typ))
            self.k_slot_of_metatable[typ] = #self.constants
        end
    end

    -- String Literals
    for _, func in ipairs(self.module.functions) do
        for cmd in ir.iter(func.blocks) do
            for _, v in ipairs(ir.get_srcs(cmd)) do
                if v._tag == "ir.Value.String" then
                    local str = v.value
                    if not self.k_slot_of_string[str] then
                        table.insert(self.constants, coder.Constant.String(str))
                        self.k_slot_of_string[str] = #self.constants
                    end
                end
            end
        end
    end

end

local function upvalue_slot(ix)
    return string.format("&K->uv[%s].uv", C.integer(ix - 1))
end

function Coder:metatable_upvalue_slot(typ)
    local ix = assert(self.k_slot_of_metatable[typ])
    return upvalue_slot(ix)
end

function Coder:string_upvalue_slot(str)
    local ix = assert(self.k_slot_of_string[str])
    return upvalue_slot(ix)
end

--
-- # Records
--
-- Records are implemented as full userdata.
--
-- The primitive-typed fields are represented as raw C values, and stored in a
-- struct in the block of raw memory of the userdata.
--
-- The GC-typed fields are represented as tagged TValues, and stored as
-- uservalues. (We need the tags because function values need the tag variants)

RecordCoder = util.Class()
function RecordCoder:init(owner, record_typ)
    local gc_count = 0
    local gc_index = {}
    local prim_count = 0
    local prim_index = {}
    for _, field_name in ipairs(record_typ.field_names) do
        local typ = record_typ.field_types[field_name]
        assert(not gc_index[field_name]) -- ensure that field names are not repeated
        assert(not prim_index[field_name])
        if types.is_gc(typ) then
            gc_count = gc_count + 1
            gc_index[field_name] = gc_count
        else
            prim_count = prim_count + 1
            prim_index[field_name] = prim_count
        end
    end

    self.owner = owner            -- Coder
    self.record_typ = record_typ  -- types.T.Record
    self.gc_count = gc_count      -- integer
    self.gc_index = gc_index      -- map string => integer
    self.prim_count = prim_count  -- integer
    self.prim_index = prim_index  -- map string => integer
end

function RecordCoder:struct_name()
    assert(self.prim_count > 0)
    local r_id = self.owner.record_ids[self.record_typ]
    return string.format("crecord_%02d", r_id)
end

function RecordCoder:get_prims_name()
    assert(self.prim_count > 0)
    local r_id = self.owner.record_ids[self.record_typ]
    return string.format("crecord_%02d_prims", r_id)
end

function RecordCoder:field_name(name)
    local i = assert(self.prim_index[name])
    return string.format("f%02d", i)
end

function RecordCoder:prims_sizeof()
    if self.prim_count > 0 then
        return string.format("sizeof(%s)", self:struct_name())
    else
        return C.integer(0)
    end
end

function RecordCoder:constructor_name()
    local r_id = self.owner.record_ids[self.record_typ]
    return string.format("crecord_%02d_new", r_id)
end

function RecordCoder:declarations()
    local declarations = {}

    assert(self.prim_count >= 0)
    assert(self.gc_count >= 0)

    -- Comment
    table.insert(declarations, C.comment(self.record_typ.name) .. "\n")

    -- Struct for the primitive fields.
    -- (C does not allow empty structs so we skip in that case)
    if self.prim_count > 0 then

        local struct_name = self:struct_name()

        local field_lines = {}
        for _, field_name in ipairs(self.record_typ.field_names) do
            local typ = self.record_typ.field_types[field_name]
            if not types.is_gc(typ) then
                local name = self:field_name(field_name)
                local decl = C.declaration(ctype(typ), name)
                local cmt = C.comment(field_name)
                table.insert(field_lines, string.format("%s; %s", decl, cmt))
            end
        end

        table.insert(declarations, util.render([[
            typedef struct {
                ${field_lines}
            } $struct_name;
        ]], {
            struct_name = struct_name,
            field_lines = table.concat(field_lines, "\n"),
        }))

        table.insert(declarations, util.render([[
            inline
            static ${struct_name} *${get_prims}(Udata *u)
            {
                char *p = cast_charp(u) + udatamemoffset($gc_count);
                return (${struct_name} *) p;
            }
        ]], {
            struct_name = struct_name,
            get_prims = self:get_prims_name(),
            gc_count = C.integer(self.gc_count),
        }))
    end

    -- Constructor
    local set_metatable
    if self.record_typ.is_upvalue_box then
        set_metatable = ""
    else
        set_metatable = util.render("rec->metatable = hvalue($mt_slot);",
            { mt_slot = self.owner:metatable_upvalue_slot(self.record_typ) })
    end

    table.insert(declarations, util.render([[
        static Udata *${constructor_name}(lua_State *L, Udata *K)
        {
 #if $nvalues > USHRT_MAX
 #error "Record type is too large"
 #endif
            Udata *rec = luaS_newudata(L, $prims_sizeof, $nvalues);
            $set_metatable
            return rec;
        }
    ]], {
        constructor_name = self:constructor_name(),
        prims_sizeof = self:prims_sizeof(),
        nvalues = C.integer(self.gc_count),
        set_metatable = set_metatable,
    }))

    return table.concat(declarations, "\n/**/\n")
end

function RecordCoder:get_prim_lvalue(rec_cvar, field_name)
    local _ = assert(self.prim_index[field_name])
    return (util.render([[$get_prims($udata)->$f]], {
        get_prims = self:get_prims_name(),
        udata = rec_cvar,
        f = self:field_name(field_name),
    }))
end

function RecordCoder:get_gc_slot(rec_cvar, field_name)
    local ix = assert(self.gc_index[field_name])
    return (util.render([[&$udata->uv[$i].uv]], {
        udata = rec_cvar,
        i = C.integer(ix - 1),
    }))
end

--
-- # GC Stuff
--

function Coder:init_gc()

    for _, func in ipairs(self.module.functions) do
        self.gc[func] = gc.compute_stack_slots(func)
    end

    for _, func in ipairs(self.module.functions) do
        local max = 0
        for cmd in ir.iter(func.blocks) do
            if cmd._tag == "ir.Cmd.CallDyn" then
                -- Although in the end the fn call leaves only ndst items in
                -- the stack, we actually need ndst+1 to appease the apicheck
                -- assertions. That's because the callee keeps the fn closure
                -- in the stack until it's right about to return.
                local nsrcs = #cmd.srcs
                local ndst  = #cmd.dsts
                max = math.max(max, nsrcs+1, ndst+1)
            end
        end
        self.max_lua_call_stack_usage[func] = max
    end
end

--
-- # Call stack managements
--
-- We keep a `base` pointer to the start of our call frame and update it every time the stack is
-- reallocated. The C compiler can't do this optimization by itself because it assumes that lots of
-- things could change L->stack.
--
-- The restorestack function should be called after every function call, when the stack may
-- potentially have been reallocated.
--
-- The savestack function needs to be called before the function calls that may reallocate the
-- stack. Calling it once in the function prologue works. Don't worry if the base_offset variable
-- goes unused because the C compiler can optimize that.
--
-- The update_stack_top should be called before function calls and GC points. We need to update
-- the stack top before a GC point so the GC can look at the right set of variables. We also need
-- to do it before function calls because the stack-gowing logic relies on having the right "top".

function Coder:update_stack_top(func, cmd)
    local offset = 0
    for _, v_id in ipairs(self.gc[func].live_gc_vars[cmd]) do
        local slot = self.gc[func].slot_of_variable[v_id]
        offset = math.max(offset, slot + 1)
    end
    return util.render("L->top.p = base + $offset;", { offset = C.integer(offset) })
end

function Coder:savestack()
    return [[ptrdiff_t base_offset = savestack(L, base);]]
end

function Coder:restorestack()
    return [[base = restorestack(L, base_offset);]]
end

--
-- # Generate Cmd
--

local gen_cmd = {}

gen_cmd["Move"] = function(self, cmd, _func)
    local dst = self:c_var(cmd.dst)
    local src = self:c_value(cmd.src)
    return (util.render([[ $dst = $src; ]], { dst = dst, src = src }))
end

gen_cmd["Unop"] = function(self, cmd, _func)
    local dst = self:c_var(cmd.dst)
    local x = self:c_value(cmd.src)

    -- For when we can directly translate to a C operator:
    local function unop(op)
        return (util.render([[ $dst = ${op}$x; ]], {
            op = op , dst = dst, x = x }))
    end

    local function int_neg()
        return (util.render([[ $dst = intop(-, 0, $x); ]], {
            dst = dst, x = x }))
    end

    local function arr_len()
        return (util.render([[
            ${check_no_metatable}
            $dst = luaH_getn($x);
        ]], {
            check_no_metatable = check_no_metatable(self, x, cmd.loc),
            line = C.integer(cmd.loc.line),
            dst = dst,
            x = x
        }))
    end

    local function str_len()
        return (util.render([[ $dst = tsslen($x); ]], {
            dst = dst, x = x }))
    end

    local op = cmd.op
    if     op == "ArrLen"  then return arr_len()
    elseif op == "StrLen"  then return str_len()
    elseif op == "IntNeg"  then return int_neg()
    elseif op == "FltNeg"  then return unop("-")
    elseif op == "BitNeg"  then return unop("~")
    elseif op == "BoolNot" then return unop("!")
    else
        error("impossible")
    end
end

gen_cmd["Binop"] = function(self, cmd, _func)
    local dst = self:c_var(cmd.dst)
    local x = self:c_value(cmd.src1)
    local y = self:c_value(cmd.src2)

    -- For when we can be directly translate to a C operator:
    local function binop(op)
        return (util.render([[ $dst = $x $op $y; ]], {
            op = op, dst = dst, x = x, y = y }))
    end

    -- For relational ops, which look better with extra parens:
    local function binop_paren(op)
        return (util.render([[ $dst = ($x $op $y); ]], {
            op = op, dst = dst, x = x, y = y }))
    end

    -- For integer ops with two's-complement wraparound:
    local function int_binop(op)
        return (util.render([[ $dst = intop($op, $x, $y); ]], {
            op = op, dst = dst, x = x, y = y }))
    end

    -- For integer division and modulus:
    local function int_division(fname)
        local line = cmd.loc.line
        return (util.render([[ $dst = $fname(L, $x, $y, PALLENE_SOURCE_FILE, $line); ]], {
            fname = fname,
            dst = dst,
            x = x,
            y = y,
            line = C.integer(line)
        }))
    end

    local function flt_divi()
        return (util.render([[ $dst = floor($x / $y); ]], {
            dst = dst, x = x, y = y }))
    end

    local function flt_mod()
        return (util.render([[ $dst = luaV_modf(L, $x, $y); ]], {
            dst = dst, x = x, y = y }))
    end

    -- For integer shift:
    local function shift(fname)
        return (util.render([[ $dst = $fname($x, $y); ]], {
            fname = fname, dst = dst, x = x, y = y }))
    end

    local function pow()
       return (util.render([[ $dst = pow($x, $y); ]], {
            dst = dst, x = x, y = y }))
    end

    local function equalobj(is_eq)
        local neg = is_eq and "" or "!"
        return (util.render([[ $dst = ${neg}luaV_equalobj(L, &$x, &$y); ]], {
            dst = dst, neg = neg, x = x, y = y }))
    end

    local function strcmp(op)
        return (util.render([[ $dst = (luaV_strcmp($x, $y) $op 0); ]], {
            dst = dst, x = x, y = y, op = op }))
    end

    local op = cmd.op
    if     op == "IntAdd"    then return int_binop("+")
    elseif op == "IntSub"    then return int_binop("-")
    elseif op == "IntMul"    then return int_binop("*")
    elseif op == "IntDivi"   then return int_division("pallene_int_divi")
    elseif op == "IntMod"    then return int_division("pallene_int_modi")
    elseif op == "FltAdd"    then return binop("+")
    elseif op == "FltSub"    then return binop("-")
    elseif op == "FltMul"    then return binop("*")
    elseif op == "FltDivi"   then return flt_divi()
    elseif op == "FltMod"    then return flt_mod()
    elseif op == "FltDiv"    then return binop("/")
    elseif op == "BitAnd"    then return int_binop("&")
    elseif op == "BitOr"     then return int_binop("|")
    elseif op == "BitXor"    then return int_binop("^")
    elseif op == "BitLShift" then return shift("pallene_shiftL")
    elseif op == "BitRShift" then return shift("pallene_shiftR")
    elseif op == "FltPow"    then return pow()
    elseif op == "AnyEq"     then return equalobj(true)
    elseif op == "AnyNeq"    then return equalobj(false)
    elseif op == "NilEq"     then return binop_paren("==")
    elseif op == "NilNeq"    then return binop_paren("!=")
    elseif op == "BoolEq"    then return binop_paren("==")
    elseif op == "BoolNeq"   then return binop_paren("!=")
    elseif op == "IntEq"     then return binop_paren("==")
    elseif op == "IntNeq"    then return binop_paren("!=")
    elseif op == "IntLt"     then return binop_paren("<")
    elseif op == "IntGt"     then return binop_paren(">")
    elseif op == "IntLeq"    then return binop_paren("<=")
    elseif op == "IntGeq"    then return binop_paren(">=")
    elseif op == "FltEq"     then return binop_paren("==")
    elseif op == "FltNeq"    then return binop_paren("!=")
    elseif op == "FltLt"     then return binop_paren("<")
    elseif op == "FltGt"     then return binop_paren(">")
    elseif op == "FltLeq"    then return binop_paren("<=")
    elseif op == "FltGeq"    then return binop_paren(">=")
    elseif op == "StrEq"     then return strcmp("==")
    elseif op == "StrNeq"    then return strcmp("!=")
    elseif op == "StrLt"     then return strcmp("<")
    elseif op == "StrGt"     then return strcmp(">")
    elseif op == "StrLeq"    then return strcmp("<=")
    elseif op == "StrGeq"    then return strcmp(">=")
    elseif op == "FunctionEq"  then return equalobj(true)
    elseif op == "FunctionNeq" then return equalobj(false)
    elseif op == "ArrayEq"   then return binop_paren("==")
    elseif op == "ArrayNeq"  then return binop_paren("!=")
    elseif op == "TableEq"   then return binop_paren("==")
    elseif op == "TableNeq"  then return binop_paren("!=")
    elseif op == "RecordEq"  then return binop_paren("==")
    elseif op == "RecordNeq" then return binop_paren("!=")
    else
        print("OP=", op)
        error("impossible")
    end
end

gen_cmd["Concat"] = function(self, cmd, _func)
    local dst = self:c_var(cmd.dst)

    local init_input_array = {}
    for ix, srcv in ipairs(cmd.srcs) do
        local src = self:c_value(srcv)
        table.insert(init_input_array,
            util.render([[ ss[$i] = $src; ]], {
                i = C.integer(ix - 1),
                src = src,
            }))
    end

    return (util.render([[
        {
            TString *ss[$N];
            ${init_input_array};
            $dst = pallene_string_concatN(L, $N, ss);
        }
    ]], {
        dst = dst,
        N = C.integer(#cmd.srcs),
        init_input_array = table.concat(init_input_array, "\n"),
    }))
end

gen_cmd["ToFloat"] = function(self, cmd, _func)
    local dst = self:c_var(cmd.dst)
    local v = self:c_value(cmd.src)
    return util.render([[ $dst = (lua_Number) $v; ]], { dst = dst, v = v })
end

gen_cmd["ToDyn"] = function(self, cmd, _func)
    local dst = self:c_var(cmd.dst)
    local src = self:c_value(cmd.src)
    local src_typ = cmd.src_typ
    return (set_stack_slot(src_typ, "&"..dst, src))
end

gen_cmd["FromDyn"] = function(self, cmd, _func)
    local dst = self:c_var(cmd.dst)
    local src = self:c_value(cmd.src)
    local dst_typ = cmd.dst_typ
    return self:get_stack_slot(dst_typ, dst, "&"..src,
        cmd.loc, "downcasted value")
end

gen_cmd["IsTruthy"] = function(self, cmd, _func)
    local dst = self:c_var(cmd.dst)
    local src = self:c_value(cmd.src)
    return (util.render([[ $dst = pallene_is_truthy(&$src); ]], {
        dst = dst, src = src }))
end

gen_cmd["IsNil"] = function(self, cmd, _func)
    local dst = self:c_var(cmd.dst)
    local src = self:c_value(cmd.src)
    return (util.render([[ $dst = ttisnil(&$src); ]], {
        dst = dst, src = src }))
end

gen_cmd["NewArr"] = function(self, cmd, _func)
    local dst = self:c_var(cmd.dst)
    local n   = self:c_value(cmd.src_size)
    return (util.render([[ $dst = pallene_createtable(L, $n, 0); ]], {
        dst = dst, n = n,
    }))
end

gen_cmd["GetArr"] = function(self, cmd, _func)
    local dst = self:c_var(cmd.dst)
    local arr = self:c_value(cmd.src_arr)
    local i   = self:c_value(cmd.src_i)
    local dst_typ = cmd.dst_typ
    local line = C.integer(cmd.loc.line)

    return (util.render([[
        {
            pallene_renormalize_array(L, $arr, $i, PALLENE_SOURCE_FILE, $line);
            TValue *slot = &$arr->array[$i - 1];
            $get_slot
        }
    ]], {
        arr = arr,
        i = i,
        line = line,
        get_slot = self:get_luatable_slot(dst_typ, dst, "slot", arr,
            cmd.loc, "array element"),
    }))
end

gen_cmd["SetArr"] = function(self, cmd, _func)
    local arr = self:c_value(cmd.src_arr)
    local i   = self:c_value(cmd.src_i)
    local v   = self:c_value(cmd.src_v)
    local src_typ = cmd.src_typ
    local line = C.integer(cmd.loc.line)
    return (util.render([[
        {
            pallene_renormalize_array(L, $arr, $i, PALLENE_SOURCE_FILE, $line);
            TValue *slot = &$arr->array[$i - 1];
            ${set_heap_slot}
        }
    ]], {
        arr = arr,
        i = i,
        v = v,
        line = line,
        set_heap_slot = set_heap_slot(src_typ, "slot", v, arr),
    }))
end

gen_cmd["NewTable"] = function(self, cmd, _func)
    local dst = self:c_var(cmd.dst)
    local n   = self:c_value(cmd.src_size)
    return (util.render([[ $dst = pallene_createtable(L, 0, $n); ]], {
        dst = dst,
        n = n,
    }))
end

gen_cmd["GetTable"] = function(self, cmd, _func)
    local dst = self:c_var(cmd.dst)
    local tab = self:c_value(cmd.src_tab)
    local key = self:c_value(cmd.src_k)
    local dst_typ = cmd.dst_typ

    assert(cmd.src_k._tag == "ir.Value.String")
    local field_name = cmd.src_k.value

    return util.render([[
        {
            static int cache = -1;
            TValue *slot = pallene_getstr($field_len, $tab, $key, &cache);
            ${get_slot}
        }
    ]], {
        field_len = tostring(#field_name),
        tab = tab,
        key = key,
        get_slot = self:get_luatable_slot(dst_typ, dst, "slot", tab, cmd.loc, "table field"),
    })
end

gen_cmd["SetTable"] = function(self, cmd, _func)
    local tab = self:c_value(cmd.src_tab)
    local key = self:c_value(cmd.src_k)
    local val = self:c_value(cmd.src_v)
    local src_typ = cmd.src_typ

    assert(cmd.src_k._tag == "ir.Value.String")
    local field_name = cmd.src_k.value

    return util.render([[
        {
            TValue keyv; ${init_keyv}
            static int cache = -1;
            TValue *slot = pallene_getstr($field_len, $tab, $key, &cache);
            if (l_unlikely(isabstkey(slot))) {
                TValue valv; ${init_valv}
                luaH_newkey(L, $tab, &keyv, &valv);
            } else {
                ${set_slot}
            }
            ${barrier};
        }
    ]], {
        field_len = tostring(#field_name),
        tab = tab,
        key = key,
        val = val,
        init_keyv = set_stack_slot(types.T.String(), "&keyv", key),
        init_valv = set_stack_slot(src_typ, "&valv", val),
        -- Here we use set_stack_slot slot on a heap object, because
        -- we call the barrier by hand outside the if statement.
        set_slot = set_stack_slot(src_typ, "slot", val),
        barrier = gc_barrier(src_typ, val, tab),
    })
end

gen_cmd["NewRecord"] = function(self, cmd, _func)
    local rc = self.record_coders[cmd.rec_typ]
    local rec = self:c_var(cmd.dst)
    return (util.render([[$rec = $constructor(L, K);]] , {
            rec = rec,
            constructor = rc:constructor_name(),
        }))
end

gen_cmd["GetField"] = function(self, cmd, _func)
    local rec_typ = cmd.rec_typ
    local rc = self.record_coders[rec_typ]

    local dst = self:c_var(cmd.dst)
    local rec = self:c_value(cmd.src_rec)
    local field_name = cmd.field_name

    local f_typ = rec_typ.field_types[field_name]
    if types.is_gc(f_typ) then
        local slot = rc:get_gc_slot(rec, field_name)
        return unchecked_get_slot(f_typ, dst, slot)
    else
        return (util.render([[
            $dst = $lval;
        ]], {
            dst = dst,
            lval = rc:get_prim_lvalue(rec, field_name),
        }))
    end
end

gen_cmd["SetField"] = function(self, cmd, _func)
    local rec_typ = cmd.rec_typ
    local rc = self.record_coders[rec_typ]

    local rec = self:c_value(cmd.src_rec)
    local v   = self:c_value(cmd.src_v)
    local field_name = cmd.field_name

    local f_typ = rec_typ.field_types[field_name]
    if types.is_gc(f_typ) then
        local slot = rc:get_gc_slot(rec, field_name)
        return (set_heap_slot(f_typ, slot, v, rec))
    else
        local lval = rc:get_prim_lvalue(rec, field_name)
        return (util.render([[$lval = $v;]], { lval = lval, v = v }))
    end
end

gen_cmd["NewClosure"] = function (self, cmd, _func)
    local func = self.module.functions[cmd.f_id]

    -- The number of upvalues must fit inside a byte (the nupvalues in the ClosureHeader).
    -- However, we must check this limit ourselves, because luaF_newCclosure doesn't. If we have too
    -- many upvalues then that internal Lua function can overflow and do weird things.
    local num_upvalues = #func.captured_vars+ 1
    assert(num_upvalues <= 255)

    return util.render([[
        {
            CClosure *ccl = luaF_newCclosure(L, $num_upvalues);
            ccl->f = $lua_entry_point;
            setuvalue(L, &ccl->upvalue[0], K);
            setclCvalue(L, &$dst, ccl);
        }
    ]], {
        num_upvalues = C.integer(num_upvalues),
        dst = self:c_var(cmd.dst),
        lua_entry_point = self:lua_entry_point_name(cmd.f_id),
    })
end

gen_cmd["InitUpvalues"] = function(self, cmd, _func)
    local func = self.module.functions[cmd.f_id]

    assert(cmd.src_f._tag == "ir.Value.LocalVar")
    local cclosure = string.format("clCvalue(&%s)", self:c_var(cmd.src_f.id))

    local capture_upvalues = {}
    for i, val in ipairs(cmd.srcs) do
        local typ   = func.captured_vars[i].typ
        local c_val = self:c_value(val)
        local upvalue_dst = string.format("&(ccl->upvalue[%s])", C.integer(i))

        -- Even though the CClosure is a heap object, it is safe to use `set_stack_slot` as
        -- there are no operations in between the closure's creation and the upvalue initialization
        -- that may trigger a GC Cycle.
        table.insert(capture_upvalues, set_stack_slot(typ, upvalue_dst, c_val))
    end

    return util.render([[
        /**/
        {
            CClosure* ccl = $cclosure;
            $capture_upvalues
        }
        /**/
    ]], {
        cclosure = cclosure,
        capture_upvalues = table.concat(capture_upvalues, "\n"),
    })
end

gen_cmd["CallStatic"] = function(self, cmd, func)
    local dsts = {}
    for i, dst in ipairs(cmd.dsts) do
        dsts[i] = dst and self:c_var(dst)
    end
    local xs = {}
    for _, x in ipairs(cmd.srcs) do
        table.insert(xs, self:c_value(x))
    end

    local parts = {}

    local f_val = cmd.src_f
    local f_id, cclosure
    if f_val._tag == "ir.Value.Upvalue" then
        f_id = assert(func.f_id_of_upvalue[f_val.id])
        cclosure = string.format("clCvalue(&%s)", self:c_value(f_val))
    elseif f_val._tag == "ir.Value.LocalVar" then
        f_id = assert(func.f_id_of_local[f_val.id])
        cclosure = string.format("clCvalue(&%s)", self:c_value(f_val))
    else
        tagged_union.error(f_val._tag)
    end

    table.insert(parts, self:update_stack_top(func, cmd))

    if self.flags.use_traceback then
        table.insert(parts, string.format("PALLENE_SETLINE(%d);\n",
            func.loc and func.loc.line or 0))
    end

    table.insert(parts, self:call_pallene_function(dsts, f_id, cclosure, xs, nil))
    table.insert(parts, self:restorestack())
    return table.concat(parts, "\n")
end

gen_cmd["CallDyn"] = function(self, cmd, func)
    local f_typ = cmd.f_typ
    local dsts = {}
    for i, dst in ipairs(cmd.dsts) do
        dsts[i] = dst and self:c_var(dst)
    end

    local push_arguments = {}
    table.insert(push_arguments, self:push_to_stack(f_typ, self:c_value(cmd.src_f)))
    for i = 1, #f_typ.arg_types do
        local typ = f_typ.arg_types[i]
        table.insert(push_arguments, self:push_to_stack(typ, self:c_value(cmd.srcs[i])))
    end

    local pop_results = {}
    for i = #f_typ.ret_types, 1, -1 do
        local typ = f_typ.ret_types[i]
        local get_slot = self:get_stack_slot(typ, dsts[i], "slot", cmd.loc, "return value #%d", i)
        table.insert(pop_results, util.render([[
            {
                L->top.p--;
                TValue *slot = s2v(L->top.p);
                $get_slot
            }
        ]], {
            get_slot = get_slot
        }))
    end

    local setline = ""
    if self.flags.use_traceback then
        setline = util.render([[ PALLENE_SETLINE($line); ]], {
            line = C.integer(func.loc and func.loc.line or 0)
        })
    end

    return util.render([[
        ${update_stack_top}
        ${push_arguments}
        ${setline}
        lua_call(L, $nargs, $nrets);
        ${pop_results}
        ${restore_stack}
    ]], {
        update_stack_top = self:update_stack_top(func, cmd),
        push_arguments = table.concat(push_arguments, "\n"),
        setline = setline,
        pop_results = table.concat(pop_results, "\n"),
        nargs = C.integer(#f_typ.arg_types),
        nrets = C.integer(#f_typ.ret_types),
        restore_stack = self:restorestack(),
    })
end

gen_cmd["BuiltinIoWrite"] = function(self, cmd, _func)
    local v = self:c_value(cmd.srcs[1])
    return util.render([[ pallene_io_write(L, $v); ]], { v = v })
end

gen_cmd["BuiltinMathAbs"] = function(self, cmd, _func)
    local dst = self:c_var(cmd.dsts[1])
    local v = self:c_value(cmd.srcs[1])
    return util.render([[ $dst = l_mathop(fabs)($v); ]], { dst = dst, v = v })
end

gen_cmd["BuiltinMathCeil"] = function(self, cmd, _func)
    local dst = self:c_var(cmd.dsts[1])
    local v = self:c_value(cmd.srcs[1])
    local line = cmd.loc.line
    return util.render([[ $dst = pallene_math_ceil(L, PALLENE_SOURCE_FILE, $line, $v); ]], {
        dst = dst, v = v, line = C.integer(line) })
end

gen_cmd["BuiltinMathFloor"] = function(self, cmd, _func)
    local dst = self:c_var(cmd.dsts[1])
    local v = self:c_value(cmd.srcs[1])
    local line = cmd.loc.line
    return util.render([[ $dst = pallene_math_floor(L, PALLENE_SOURCE_FILE, $line, $v); ]], {
        dst = dst, v = v, line = C.integer(line) })
end

gen_cmd["BuiltinMathFmod"] = function(self, cmd, _func)
    local dst = self:c_var(cmd.dsts[1])
    local x = self:c_value(cmd.srcs[1])
    local y = self:c_value(cmd.srcs[2])
    return util.render([[ $dst = l_mathop(fmod)($x, $y); ]], { dst = dst, x = x, y = y })
end

gen_cmd["BuiltinMathExp"] = function(self, cmd, _func)
    local dst = self:c_var(cmd.dsts[1])
    local v = self:c_value(cmd.srcs[1])
    return util.render([[ $dst = l_mathop(exp)($v); ]], { dst = dst, v = v })
end

-- We are introducing math.ln as a workaround for 1 param math.log
-- Because Pallene currently cannot handle optional parameters,
-- we've decided to introduce math.ln as a replacement for single param log(x).
-- But for --emit-lua, we must do something to make the code work in pure Lua.
-- For now, the easiest thing to do is inject math.ln = math.log at the top.
-- A smarter routine would replace math.ln with math.log.
gen_cmd["BuiltinMathLn"] = function(self, cmd, _func)
    local dst = self:c_var(cmd.dsts[1])
    local v = self:c_value(cmd.srcs[1])
    return util.render([[ $dst = l_mathop(log)($v); ]], { dst = dst, v = v })
end

gen_cmd["BuiltinMathLog"] = function(self, cmd, _func)
    local dst = self:c_var(cmd.dsts[1])
    local v = self:c_value(cmd.srcs[1])
    local b = self:c_value(cmd.srcs[2])
    return util.render([[ $dst = pallene_math_log($v, $b); ]],
        { dst = dst, v = v, b = b })
end

gen_cmd["BuiltinMathModf"] = function(self, cmd, _func)
    local dst1 = self:c_var(cmd.dsts[1])
    local dst2 = self:c_var(cmd.dsts[2])
    local v = self:c_value(cmd.srcs[1])
    local line = cmd.loc.line
    return util.render([[ $dst1 = pallene_math_modf(L, PALLENE_SOURCE_FILE, $line, $v, &$dst2); ]], {
        dst1 = dst1, dst2 = dst2, v = v, line = C.integer(line) })
end

gen_cmd["BuiltinMathPow"] = function(self, cmd, _func)
    local dst = self:c_var(cmd.dsts[1])
    local x = self:c_value(cmd.srcs[1])
    local y = self:c_value(cmd.srcs[2])
    return util.render([[ $dst = l_mathop(pow)($x, $y); ]], { dst = dst, x = x, y = y })
end

gen_cmd["BuiltinMathSqrt"] = function(self, cmd, _func)
    local dst = self:c_var(cmd.dsts[1])
    local v = self:c_value(cmd.srcs[1])
    return util.render([[ $dst = l_mathop(sqrt)($v); ]], { dst = dst, v = v })
end

gen_cmd["BuiltinStringChar"] = function(self, cmd, _func)
    local dst = self:c_var(cmd.dsts[1])
    local v = self:c_value(cmd.srcs[1])
    local line = cmd.loc.line
    return util.render([[ $dst = pallene_string_char(L, PALLENE_SOURCE_FILE, $line, $v); ]], {
        dst = dst, v = v, line = C.integer(line) })
end

gen_cmd["BuiltinStringSub"] = function(self, cmd, _func)
    local dst = self:c_var(cmd.dsts[1])
    local str = self:c_value(cmd.srcs[1])
    local i   = self:c_value(cmd.srcs[2])
    local j   = self:c_value(cmd.srcs[3])
    return util.render([[ $dst = pallene_string_sub(L, $str, $i, $j); ]], {
        dst = dst, str = str, i = i, j = j })
end

gen_cmd["BuiltinType"] = function(self, cmd, _func)
    local dst = self:c_var(cmd.dsts[1])
    local v = self:c_value(cmd.srcs[1])
    return util.render([[ $dst = pallene_type_builtin(L, $v); ]], { dst = dst, v = v })
end

gen_cmd["BuiltinTostring"] = function(self, cmd, _func)
    local dst = self:c_var(cmd.dsts[1])
    local v = self:c_value(cmd.srcs[1])
    local line = cmd.loc.line
    return util.render([[ $dst = pallene_tostring(L, PALLENE_SOURCE_FILE, $line, $v); ]], {
        dst = dst, line = C.integer(line), v = v })
end

--
-- Control flow
--

gen_cmd["Nop"] = function(self, _cmd, _func)
    return ""
end

gen_cmd["Return"] = function(self, cmd)
    local frameexit = ""
    if self.flags.use_traceback then
        frameexit = "PALLENE_FRAMEEXIT();"
    end

    if #cmd.srcs == 0 then
        return util.render([[ ${fexit}
        return; ]], { fexit = frameexit })
    else
        -- We assign the dsts from right to left, in order to match Lua's semantics when a
        -- destination variable appears more than once in the LHS. For example, in `x,x = f()`.
        -- For a more in-depth discussion, see the implementation of ast.Stat.Assign in to_ir.lua
        local returns = {}
        for i = #cmd.srcs, 2, -1 do
            local src = self:c_value(cmd.srcs[i])
            table.insert(returns,
                util.render([[ *$reti = $v; ]], { reti = self:c_ret_var(i), v = src }))
        end
        local src1 = self:c_value(cmd.srcs[1])
        table.insert(returns, util.render([[ ${fexit}
        return $v; ]], { fexit = frameexit, v = src1 }))
        return table.concat(returns, "\n")
    end
end

gen_cmd["InitFor"] = function(self, cmd, func)
    local typ = func.vars[cmd.dst_i].typ

    local macro
    if     typ._tag == "types.T.Integer" then
        macro = "PALLENE_INT_INIT_FOR_LOOP"
    elseif typ._tag == "types.T.Float" then
        macro = "PALLENE_FLT_INIT_FOR_LOOP"
    else
        tagged_union.error(typ._tag)
    end

    return (util.render([[
        ${macro}($i, $cond, $iter, $count, $start, $limit, $step)
    ]], {
        macro = macro,
        i     = self:c_var(cmd.dst_i),
        cond  = self:c_var(cmd.dst_cond),
        iter  = self:c_var(cmd.dst_iter),
        count = self:c_var(cmd.dst_count),
        start = self:c_value(cmd.src_start),
        limit = self:c_value(cmd.src_limit),
        step  = self:c_value(cmd.src_step),
    }))
end

gen_cmd["IterFor"] = function(self, cmd, func)
    local typ = func.vars[cmd.dst_i].typ

    local macro
    if     typ._tag == "types.T.Integer" then
        macro = "PALLENE_INT_ITER_FOR_LOOP"
    elseif typ._tag == "types.T.Float" then
        macro = "PALLENE_FLT_ITER_FOR_LOOP"
    else
        tagged_union.error(typ._tag)
    end

    return (util.render([[
        ${macro}($i, $cond, $iter, $count, $start, $limit, $step)
    ]], {
        macro = macro,
        i     = self:c_var(cmd.dst_i),
        cond  = self:c_var(cmd.dst_cond),
        iter  = self:c_var(cmd.dst_iter),
        count = self:c_var(cmd.dst_count),
        start = self:c_value(cmd.src_start),
        limit = self:c_value(cmd.src_limit),
        step  = self:c_value(cmd.src_step),
    }))
end

gen_cmd["CheckGC"] = function(self, cmd, func)
    return util.render([[ luaC_condGC(L, ${update_stack_top}, (void)0); ]], {
        update_stack_top = self:update_stack_top(func, cmd) })
end

function Coder:generate_blocks(func)
    local out = ""
    for i,block in ipairs(func.blocks) do
        -- putting a "(void)0" at the label so compiler doesn't complain about dangling labels
        local content = self:c_label(i) .. ":(void)0;\n"
        for _,cmd in ipairs(block.cmds) do
            content = content .. self:generate_cmd(func, cmd) .. "\n"
        end
        local jump_cond = ""
        if block.jmp_false then
            jump_cond = util.render("if(!($v)) {goto $l;}\n", {
                v = self:c_value(block.jmp_false.src_condition),
                l = self:c_label(block.jmp_false.target),
            })
        end
        local jump = ""
        if block.next and block.next ~= i + 1 then
            jump = "goto " .. self:c_label(block.next) .. ";\n"
        end
        content = content .. jump_cond .. jump
        out = out .. content
    end
    return out
end

function Coder:generate_cmd(func, cmd)
    assert(tagged_union.typename(cmd._tag) == "ir.Cmd")
    local name = tagged_union.consname(cmd._tag)
    local f = assert(gen_cmd[name], "impossible")
    local out = f(self, cmd, func)

    for _, v_id in ipairs(ir.get_dsts(cmd)) do
        local n = self.gc[func].slot_of_variable[v_id]
        if n then
            local typ = func.vars[v_id].typ
            local slot = util.render([[s2v(base + $n)]], { n = C.integer(n) })
            out = out .. "\n" .. set_stack_slot(typ, slot, self:c_var(v_id))
        end
    end

    return out
end

--
-- # Generate file
--

local function section_comment(msg)
    local ruler = string.rep("-", #msg)
    local lines = {}
    table.insert(lines, "/**/")
    table.insert(lines, "/* " .. ruler .. " */")
    table.insert(lines, "/* " .. msg   .. " */")
    table.insert(lines, "/* " .. ruler .. " */")
    table.insert(lines, "/**/")
    return table.concat(lines, "\n")
end

function Coder:generate_module_header()

    local out = {}

    table.insert(out, "/* This file was generated by the Pallene compiler. Do not edit by hand */")
    table.insert(out, "")
    table.insert(out, string.format("#define PALLENE_SOURCE_FILE %s", C.string(self.filename)))
    table.insert(out, "")

    table.insert(out, "/* ------------------------ */")
    table.insert(out, "/* Pallene standard library */")
    table.insert(out, "/* ------------------------ */")
    table.insert(out, "")
    table.insert(out, pallenelib)

    return table.concat(out, "\n")
end

function Coder:generate_module_body()

    local out = {}

    table.insert(out, section_comment("Records"))
    for _, typ in ipairs(self.module.record_types) do
        local rc = self.record_coders[typ]
        table.insert(out, rc:declarations())
    end

    table.insert(out, section_comment("Function Prototypes"))
    for f_id = 1, #self.module.functions do
        table.insert(out, self:pallene_entry_point_declaration(f_id) .. ";")
    end

    for f_id = 1, #self.module.functions do
        table.insert(out, self:lua_entry_point_declaration(f_id) .. ";")
    end

    table.insert(out, section_comment("Pallene Entry Points"))
    for f_id = 1, #self.module.functions do
        table.insert(out, self:pallene_entry_point_definition(f_id))
    end

    table.insert(out, section_comment("Lua Entry Points"))
    for f_id = 1, #self.module.functions do
        table.insert(out, self:lua_entry_point_definition(f_id))
    end

    table.insert(out, self:generate_luaopen_function())

    return C.reformat(table.concat(out, "\n/**/\n"))
end

function Coder:generate_luaopen_function()

    local init_constants = {}
    for ix, upv in ipairs(self.constants) do
        local tag = upv._tag
        local is_upvalue_box = false

        if     tag == "coder.Constant.Metatable" then
            is_upvalue_box = upv.typ.is_upvalue_box
            if not is_upvalue_box then
                table.insert(init_constants, util.render([[
                    luaL_newmetatable(L, $type_name);
                    lua_pushstring(L, "__metatable");
                    lua_pushboolean(L, 0);
                    lua_settable(L, -3); ]], {
                        type_name = C.string(upv.typ.name)
                    }))
            end
        elseif tag == "coder.Constant.String" then
            table.insert(init_constants, util.render([[
                lua_pushstring(L, $str);]], {
                    str = C.string(upv.str)
                }))
        -- Will be used if compiling with `--use-traceback`
        elseif tag == "coder.Constant.DebugUserdata" then
            table.insert(init_constants, [[
                /* Initialize Pallene Tracer. */
                lua_pushlightuserdata(L, (void *) pallene_tracer_init(L));
            ]]);
        elseif tag == "coder.Constant.DebugMetatable" then
            table.insert(init_constants, [[
                /* `pallene_tracer_init` fn pushes the finalizer metatable into the stack. */
            ]])
        else
            tagged_union.error(tag)
        end

        if not is_upvalue_box then
            table.insert(init_constants, util.render([[
                lua_setiuservalue(L, globals, $ix);
                /**/
            ]], {
                ix = C.integer(ix),
            }))
        end
    end

    local init_initializers = util.render([[
        lua_pushvalue(L, globals);
        lua_pushcclosure(L, ${init_function}, 1);
        lua_call(L, 0, 1);
    ]], {
        init_function = self:lua_entry_point_name(1),
    })

    -- NOTE: Version compatibility
    -- ---------------------------
    -- We have both a compile-time and a run-time test. The compile-time test ensures that the
    -- version of Lua is exactly the one that this version of Pallene supports. The run-time test
    -- checks that the Lua version didn't change behind our backs, after the Pallene module was
    -- compiled. For example, if you update the Lua library but don't recompile the Pallene module.

    return (util.render([[
        int ${name}(lua_State *L)
        {

            #if LUA_VERSION_RELEASE_NUM != 50406
            #error "Lua version must be exactly 5.4.6"
            #endif

            luaL_checkcoreversion(L);

            /**/
            /* Constants */
            /**/

#if $n_upvalues > USHRT_MAX
#error "Too many string literals or record types"
#endif
            lua_newuserdatauv(L, 0, $n_upvalues);
            int globals = lua_gettop(L);
            /**/
            ${init_constants}

            /**/
            /* Toplevel Module Code */
            /**/

            ${init_initializers}

            return 1;
        }
    ]], {
        name = "luaopen_" .. self.modname,
        n_upvalues = C.integer(#self.constants),
        init_constants = table.concat(init_constants, "\n"),
        init_initializers = init_initializers,
    }))
end

return coder
