local C = require "pallene.C"
local ir = require "pallene.ir"
local location = require "pallene.location"
local types = require "pallene.types"
local util = require "pallene.util"

local coder = {}

local Coder

function coder.generate(module, modname)
    local c = Coder.new(module, modname)
    local code = c:generate_module()
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
    elseif tag == "types.T.Boolean"  then return "int"
    elseif tag == "types.T.Integer"  then return "lua_Integer"
    elseif tag == "types.T.Float"    then return "lua_Number"
    elseif tag == "types.T.String"   then return "TString *"
    elseif tag == "types.T.Function" then return "TValue"
    elseif tag == "types.T.Array"    then return "Table *"
    elseif tag == "types.T.Record"   then return "Udata *"
    elseif tag == "types.T.Value"    then return "TValue"
    else error("impossible")
    end
end

-- @returns A syntactically valid function argument or variable declaration
--          without the comma or semicolon
local function c_declaration(ctyp, name)
    return string.format("%s %s", ctyp, name)
end

--
--
--

Coder = {}
Coder.__index = Coder

function Coder.new(module, modname)
    local self = setmetatable({}, Coder)
    self.module = module
    self.modname = modname
    self.func = false
    return self
end

--
-- #slots
--

-- @param src_slot: The TValue* to read from
local function get_slot(typ, src_slot)
    local tmpl
    local tag = typ._tag
    if     tag == "types.T.Nil"      then tmpl = "0"
    elseif tag == "types.T.Boolean"  then tmpl = "bvalue($src)"
    elseif tag == "types.T.Integer"  then tmpl = "ivalue($src)"
    elseif tag == "types.T.Float"    then tmpl = "fltvalue($src)"
    elseif tag == "types.T.String"   then tmpl = "tsvalue($src)"
    elseif tag == "types.T.Function" then tmpl = "*($src)"
    elseif tag == "types.T.Array"    then tmpl = "hvalue($src)"
    elseif tag == "types.T.Record"   then tmpl = "uvalue($src)"
    elseif tag == "types.T.Value"    then tmpl = "*($src)"
    else error("impossible")
    end
    return (util.render(tmpl, {src = src_slot}))
end

-- Don't forget to call barrierback if this slot belongs to a heap object!
-- @param dst_slot: The TValue* to write to
local function set_slot(typ, dst_slot, value)
    local tmpl
    local tag = typ._tag
    if     tag == "types.T.Nil"      then tmpl = "setnilvalue($dst);"
    elseif tag == "types.T.Boolean"  then tmpl = "setbvalue($dst, $src);"
    elseif tag == "types.T.Integer"  then tmpl = "setivalue($dst, $src);"
    elseif tag == "types.T.Float"    then tmpl = "setfltvalue($dst, $src);"
    elseif tag == "types.T.String"   then tmpl = "setsvalue(L, $dst, $src);"
    elseif tag == "types.T.Function" then tmpl = "setobj(L, $dst, &$src);"
    elseif tag == "types.T.Array"    then tmpl = "sethvalue(L, $dst, $src);"
    elseif tag == "types.T.Record"   then tmpl = "setuvalue(L, $dst, $src);"
    elseif tag == "types.T.Value"    then tmpl = "setobj(L, $dst, &$src);"
    else error("impossible")
    end
    return (util.render(tmpl, { dst = dst_slot, src = value }))
end

function Coder:push_to_stack(typ, value)
    return (util.render([[
        ${set_slot}
        api_incr_top(L); ]],{
            set_slot = set_slot(typ, "s2v(L->top)", value),
    }))
end

-- This function should be called when setting "v" as an element of "p", to
-- preserve the color invariants of the incremental GC.
--
-- The implementation is a specialization of luaC_barrierback that checks at
-- compile time if the child object is collectible, if possible. Additionally,
-- our version of the macros use "internal poiters" (as described by ctype())
-- instead of TValue*.
--
-- @param typ: Type of child object
-- @param p: Internal pointer to parent object
-- @param v: Internal pointer to child object
-- @returns C statementS
local function barrierback(typ, p, v)
    local tmpl
    if not types.is_gc(typ) then
        tmpl = ""
    elseif typ._tag == "types.T.Value" or typ._tag == "types.T.Function" then
        tmpl = [[pallene_barrierback_unknown_child(L, $p, &$v);]]
    else
        tmpl = [[pallene_barrierback_collectable_child(L, $p, $v);]]
    end
    return (util.render(tmpl, { p = p, v = v }))
end

--
-- #tags
--

local function pallene_type_tag(typ)
    local tag = typ._tag
    if     tag == "types.T.Nil"      then return "LUA_TNIL"
    elseif tag == "types.T.Boolean"  then return "LUA_TBOOLEAN"
    elseif tag == "types.T.Integer"  then return "LUA_TNUMINT"
    elseif tag == "types.T.Float"    then return "LUA_TNUMFLT"
    elseif tag == "types.T.String"   then return "LUA_TSTRING"
    elseif tag == "types.T.Function" then return "LUA_TFUNCTION"
    elseif tag == "types.T.Array"    then return "LUA_TTABLE"
    elseif tag == "types.T.Record"   then return "LUA_TUSERDATA"
    elseif tag == "types.T.Value"    then error("value is not a tag")
    else error("impossible")
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
    elseif tag == "types.T.Value"    then tmpl = "1"
    elseif tag == "types.T.Record"   then
        error("not implemented (record tag test)")
    else error("impossible")
    end
    return (util.render(tmpl, {slot = slot}))
end

-- Perform a run-time tag check
--
-- typ: expected type
-- slot: TValue* to be tested
-- loc: source code location (for error reporting)
-- description_fmt: Format string in lua_pushfstring format, which
--                  describes what this tag check is for.
--                  Received as a Lua string.
-- ... (extra_args): Parameters to the format string.
--                  Received as serialized C expressions.
function Coder:check_tag(typ, slot, loc, description_fmt, ...)
    if typ._tag == "types.T.Value" then
        return ""
    else
        local extra_args = table.pack(...)
        return (util.render([[
            if (PALLENE_UNLIKELY(!$test)) {
                pallene_runtime_tag_check_error(L,
                    $line, $expected_tag, rawtt($slot),
                    ${description_fmt}${opt_comma}${extra_args});
            } ]], {
                test = self:test_tag(typ, slot),
                line = C.integer(loc and loc.line or 0),
                expected_tag = pallene_type_tag(typ),
                slot = slot,
                description_fmt = C.string(description_fmt),
                opt_comma = (#extra_args == 0 and "" or ", "),
                extra_args = table.concat(extra_args, ", "),
        }))
    end
end

--
-- # Headers
--

function Coder:generate_headers()
    return [[
        #include "pallene_core.h"

        #include "lua.h"
        #include "lauxlib.h"
        #include "lualib.h"

        #include "lapi.h"
        #include "lfunc.h"
        #include "lgc.h"
        #include "lobject.h"
        #include "lstate.h"
        #include "lstring.h"
        #include "ltable.h"
        #include "lvm.h"

        #include <math.h>
    ]]
end

--
--  # Local variables
--

-- @returns the C variable name for the variable v_id
function Coder:c_var(v_id)
    return "x" .. v_id
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
        error("not implemented")
    elseif tag == "ir.Value.LocalVar" then
        return self:c_var(value.id)
    else
        error("impossible")
    end
end

-- @returns A syntactically valid function argument or variable declaration
--      for variable v_id from function f_id, and a correspong C comment, if
--      applicable. Since this may be used for either
--      a local variable or a function argument, there is no semicolon.
function Coder:c_declaration(f_id, v_id)
    local func = self.module.functions[f_id]
    local decl = func.vars[v_id]

    local ctyp = ctype(decl.typ)
    local name = self:c_var(v_id)
    local comment = decl.comment and C.comment(decl.comment) or ""

    return c_declaration(ctyp, name), comment
end

--
-- # Pallene entry point
--

function Coder:pallene_entry_point_name(f_id)
    return string.format("function_%02d", f_id)
end

function Coder:pallene_entry_point_declaration(f_id)
    local func = self.module.functions[f_id]
    local arg_types = func.typ.arg_types
    local ret_types = func.typ.ret_types
    assert(#ret_types <= 1)

    local ret = (#ret_types >= 1 and ctype(ret_types[1]) or "void")

    local args = {}
    table.insert(args, {"lua_State *L", ""})
    for i = 1, #arg_types do
        table.insert(args, {self:c_declaration(f_id, i)})
    end

    local arg_lines = {}
    for i, arg in ipairs(args) do
        local comma = (i < #args) and "," or " "
        table.insert(arg_lines, string.format("%s%s %s", arg[1], comma, arg[2]))
    end

    return (util.render([[
        static ${ret} ${name}(
            ${args}
        )]], {
            ret = ret,
            name = self:pallene_entry_point_name(f_id),
            args = table.concat(arg_lines, "\n"),
        }))
end

function Coder:pallene_entry_point_definition(f_id)
    local func = self.module.functions[f_id]
    local narg = #func.typ.arg_types
    local nret = #func.typ.ret_types

    local var_decls = {}
    for v_id = narg + 1, #func.vars do
        local decl, comment = self:c_declaration(f_id, v_id)
        table.insert(var_decls, string.format("%s; %s", decl, comment))
    end
    if nret > 0 then
        local typ = func.typ.ret_types[1]
        table.insert(var_decls, c_declaration(ctype(typ), "ret")..";")
    end

    self.func = func
    local body = self:generate_cmds(func.body)
    self.func = nil

    local prologue = {}
    table.insert(prologue, [[done: ]])
    if nret == 0 then
        table.insert(prologue, "return;")
    else
        assert(nret == 1)
        table.insert(prologue, "return ret;")
    end

    local name_comment = C.comment(string.format(
        "%s %s", func.name, location.show_line(func.loc)))

    return (util.render([[
        ${name_comment}
        ${fun_decl} {
            ${var_decls}

            ${body}

            ${prologue}
        }
    ]], {
        name_comment = name_comment,
        fun_decl = self:pallene_entry_point_declaration(f_id),
        var_decls = table.concat(var_decls, "\n"),
        body = body,
        prologue = table.concat(prologue, "\n"),
    }))
end

function Coder:call_pallene_function(dst, f_id, xs)
    local func = self.module.functions[f_id]
    local nret = #func.typ.ret_types

    local args = {}
    table.insert(args, "L")
    for _, x in ipairs(xs) do
        table.insert(args, x)
    end

    local call = util.render([[$name($args);]], {
        name = self:pallene_entry_point_name(f_id),
        args = table.concat(args, ", "),
    })

    if nret == 0 then
        assert(dst == false)
        return call
    else
        assert(dst)
        return (util.render([[$dst = $call]], {
            dst = dst,
            call = call,
        }))
    end
end

--
-- # Lua entry point
--

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
    local nargs = #func.typ.arg_types
    local nret  = #func.typ.ret_types

    local arity_check = util.render([[
        int nargs = lua_gettop(L);
        if (PALLENE_UNLIKELY(nargs != $nargs)) {
            pallene_runtime_arity_error(L, $fname, $nargs, nargs);
        }
    ]], {
        nargs = nargs,
        fname = C.string(fname),
    })

    local type_checks = {}
    for i = 1, nargs do
        local typ = func.typ.arg_types[i]
        local name = func.vars[i].comment
        table.insert(type_checks, util.render([[
            slot = s2v(base + $i);
            ${check_tag}
        ]], {
            i = C.integer(i),
            check_tag = self:check_tag(
                typ, "slot", func.loc, "argument %s", C.string(name)),

        }))
    end

    local arg_vars = {}
    local get_args = {}
    for i = 1, nargs do
        local typ = func.typ.arg_types[i]
        local slot = string.format("s2v(base + %s)", C.integer(i))
        local name = "x"..i
        arg_vars[i] = name
        table.insert(get_args, util.render([[
            $decl = $get_slot; ]], {
                decl = c_declaration(ctype(typ), name),
                get_slot = get_slot(typ, slot),
        }))
    end

    local call_and_push
    if nret == 0 then
        call_and_push = self:call_pallene_function(false, f_id, arg_vars)
    else
        assert(nret == 1)
        local typ = func.typ.ret_types[1]
        local ret = c_declaration(ctype(typ), "ret")
        call_and_push = util.render([[
            ${call}
            ${push} ]], {
                call = self:call_pallene_function(ret, f_id, arg_vars),
                push = self:push_to_stack(typ, "ret")
            })
    end

    return (util.render([[
        ${fun_decl}
        {
            StackValue *base = L->ci->func;
            TValue *slot;

            ${arity_check}

            ${type_checks}

            ${get_args}
            ${call_and_push}
            return $nret;
        }
    ]], {
        fun_decl = self:lua_entry_point_declaration(f_id),
        arity_check = arity_check,
        type_checks = table.concat(type_checks, "\n"),
        get_args = table.concat(get_args, "\n"),
        call_and_push = call_and_push,
        nret = #func.typ.ret_types,
    }))
end

--
-- # Generate Cmd
--


local gen_cmd = {}
local gen_builtin = {}

gen_cmd["Move"] = function(self, cmd)
    local dst = self:c_var(cmd.dst)
    local src = self:c_value(cmd.src)
    return (util.render([[ $dst = $src; ]], { dst = dst, src = src }))
end

gen_cmd["Unop"] = function(self, cmd)
    local dst = self:c_var(cmd.dst)
    local x = self:c_value(cmd.src)

    local function unop(op)
        -- Some unary operations can be directly translated to a C operator
        return (util.render([[ $dst = ${op}$x; ]], {
            op = op , dst = dst, x = x }))
    end

    local function int_neg()
        -- Lua and Pallene mandate two's-complement wraparound on integer arith
        return (util.render([[ $dst = intop(-, 0, $x); ]], {
            dst = dst, x = x }))
    end

    local function arr_len()
        return (util.render([[ $dst = luaH_getn($x); ]], {
            dst = dst, x = x }))
    end

    local function str_len()
        error("not implemented (string length)")
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

gen_cmd["Binop"] = function(self, cmd)
    local dst = self:c_var(cmd.dst)
    local x = self:c_value(cmd.src1)
    local y = self:c_value(cmd.src2)

    local function binop(op)
        -- Some binary operations can be directly translated to a C operator
        return (util.render([[ $dst = $x $op $y; ]], {
            op = op, dst = dst, x = x, y = y }))
    end

    local function binop_paren(op)
        -- Improved readability for relational operationss
        return (util.render([[ $dst = ($x $op $y); ]], {
            op = op, dst = dst, x = x, y = y }))
    end

    local function int_binop(op)
        -- Lua and Pallene mandate two's-complement wraparound on integer arith
        return (util.render([[ $dst = intop($op, $x, $y); ]], {
            op = op, dst = dst, x = x, y = y }))
    end

    local function int_divi()
        -- Lua and Pallene round integer division towards negative infinity,
        -- while C rounds towards zero. Here we inline luaV_div, to allow the C
        -- compiler to constant-propagate. For an explanation of the algorithm,
        -- see the comments for luaV_div.
        return (util.render([[
            if (l_castS2U($n) + 1u <= 1u) {
                if ($n == 0){
                    pallene_runtime_divide_by_zero_error(L, $line);
                } else {
                    $dst = intop(-, 0, $m);
                }
            } else {
                $dst = $m / $n;
                if (($m ^ $n) < 0 && ($m % $n) != 0) {
                    $dst -= 1;
                }
            } ]], {
                dst = dst,
                m = x,
                n = y,
                line = C.integer(cmd.loc.line),
            }))
    end

    local function int_mod()
        -- Lua and Pallene guarantee that (m == n*(m//n) + (m%n))
        -- For details, see gen_int_div, luaV_div, and luaV_mod.
        return (util.render([[
            if (l_castS2U($n) + 1u <= 1u) {
                if ($n == 0){
                    pallene_runtime_mod_by_zero_error(L, ${line});
                } else {
                    $dst = 0;
                }
            } else {
                $dst = $m % $n;
                if ($dst != 0 && ($m ^ $n) < 0) {
                    $dst += $n;
                }
            } ]], {
                dst = dst,
                m = x,
                n = y,
                line = C.integer(cmd.loc.line),
            }))
    end

    local function flt_divi()
        return (util.render([[ $dst = floor($x / $y); ]], {
            dst = dst, x = x, y = y }))
    end

    local function flt_mod()
        -- See luai_nummod
        error("not implemented (float mod)")
    end

    local function shift(shift_pos, shift_neg)
        -- In Lua and Pallene, the shift ammount in a bitshift can be any
        -- integer and the behavior is not the same as large bitshifts and
        -- negative bitshifts.
        --
        -- Most of the time, the shift amount should be a compile-time constant,
        -- in which case the C compiler should be able to simplify this down to
        -- a single shift instruction.
        --
        -- In the dynamic case with unknown "y" this implementation is a little
        -- bit faster Lua because we put the most common case under a single
        -- level of branching. (~20% speedup)
        return (util.render([[
            if (PALLENE_LIKELY(l_castS2U($y) < PALLENE_LUAINTEGER_NBITS)) {
                $dst = intop($shift_pos, $x, $y);
            } else {
                if (l_castS2U(-$y) < PALLENE_LUAINTEGER_NBITS) {
                    $dst = intop($shift_neg, $x, -$y);
                } else {
                    $dst = 0;
                }
            } ]], {
                shift_pos = shift_pos,
                shift_neg = shift_neg,
                dst = dst,
                x = x,
                y = y,
            }))

    end

    local function pow()
       return (util.render([[ $dst = pow($x, $y); ]], {
            dst = dst, x = x, y = y }))
    end

    local op = cmd.op
    if     op == "IntAdd"    then return int_binop("+")
    elseif op == "IntSub"    then return int_binop("-")
    elseif op == "IntMul"    then return int_binop("*")
    elseif op == "IntDivi"   then return int_divi()
    elseif op == "IntMod"    then return int_mod()
    elseif op == "FltAdd"    then return binop("+")
    elseif op == "FltSub"    then return binop("-")
    elseif op == "FltMul"    then return binop("*")
    elseif op == "FltDivi"   then return flt_divi()
    elseif op == "FltMod"    then return flt_mod()
    elseif op == "FltDiv"    then return binop("/")
    elseif op == "BitAnd"    then return int_binop("&")
    elseif op == "BitOr"     then return int_binop("|")
    elseif op == "BitXor"    then return int_binop("^")
    elseif op == "BitLShift" then return shift("<<", ">>")
    elseif op == "BitRShift" then return shift(">>", "<<")
    elseif op == "FltPow"    then return pow()
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
    else
        print("OP=", op)
        error("impossible")
    end
end

gen_cmd["Concat"] = function(self, _cmd)
    error("not implemented (concat)")
end

gen_cmd["ToDyn"] = function(self, cmd)
    local dst = self:c_var(cmd.dst)
    local src = self:c_value(cmd.src)
    local src_typ = ir.value_type(self.func, cmd.src)
    return (set_slot(src_typ, "&"..dst, src))
end

gen_cmd["FromDym"] = function(self, cmd)
    local dst = self:c_var(cmd.dst)
    local src = self:c_value(cmd.src)

    assert(src._tag == "ir.Value.LocalVar") -- no "value" literals
    local src_var = src.id

    local dst_typ = self.func.vars[cmd.dst].typ
    local src_typ = self.func.vars[src_var].typ

    return (util.render([[
        ${check_tag}
        $dst = $get_slot; ]], {
            dst = dst,
            check_tag = self:check_tag(dst_typ, "&"..src_var,
                    cmd.loc, "downcasted value"),
            get_slot = get_slot(src_typ, "&"..src_var),
        }))
end

gen_cmd["NewArr"] = function(self, cmd)
    local dst = self:c_var(cmd.dst)
    local n = C.integer(cmd.size_hint)
    return (util.render([[
        $dst = luaH_new(L);
        if ($n > 0) {
            luaH_resizearray(L, $dst, $n);
        } ]], {
            dst = dst,
            n = n,
        }))
end

gen_cmd["GetArr"] = function(self, cmd)
    local typ = ir.value_type(self.func, cmd.src_arr).elem
    local dst = self:c_var(cmd.dst)
    local arr = self:c_value(cmd.src_arr)
    local i   = self:c_value(cmd.src_i)
    local line = C.integer(cmd.loc.line)
    return (util.render([[
        {
            lua_Unsigned ui = ((lua_Unsigned) $i) - 1;
            if (PALLENE_UNLIKELY(ui >= $arr->sizearray)) {
                pallene_renormalize_array(L, $arr, ui, $line);
            }
            TValue *slot = &$arr->array[ui];
            ${check_tag}
            $dst = $get_slot;
        } ]], {
            dst = dst,
            arr = arr,
            i = i,
            line = line,
            check_tag = self:check_tag(typ, "slot", cmd.loc, "array element"),
            get_slot = get_slot(typ, "slot"),
        }))
end

gen_cmd["SetArr"] = function(self, cmd)
    local typ = ir.value_type(self.func, cmd.src_v)
    local arr = self:c_value(cmd.src_arr)
    local i   = self:c_value(cmd.src_i)
    local v   = self:c_value(cmd.src_v)
    local line = C.integer(cmd.loc.line)
    return (util.render([[
        {
            lua_Unsigned ui = ((lua_Unsigned) $i) - 1;
            if (PALLENE_UNLIKELY(ui >= $arr->sizearray)) {
                pallene_renormalize_array(L, $arr, ui, $line);
            }
            TValue *slot = &$arr->array[ui];
            ${set_slot} ${barrierback}
        } ]], {
            arr = arr,
            i = i,
            v = v,
            line = line,
            set_slot = set_slot(typ, "slot", v),
            barrierback = barrierback(typ, arr, v),

        }))
end

gen_cmd["NewRecord"] = function(self, _cmd)
    error("not implemented (new record)")
end

gen_cmd["GetField"] = function(self, _cmd)
    error("not implemented (get field)")
end

gen_cmd["SetField"] = function(self, _cmd)
    error("not implemented (set field)")
end

gen_cmd["CallStatic"] = function(self, cmd)
    local dst = cmd.dst and self:c_var(cmd.dst)
    local xs = {}
    for _, x in ipairs(cmd.srcs) do
        table.insert(xs, self:c_value(x))
    end
    return self:call_pallene_function(dst, cmd.f_id, xs)
end

gen_cmd["CallDyn"] = function(self, _cmd)
    error("not implemented (call dyn)")
end

gen_cmd["CallBuiltin"] = function(self, cmd)
    local f = assert(gen_builtin[cmd.builtin_name])
    return f(self, cmd)
end

gen_builtin["tofloat"] = function(self, cmd)
    local dst = self:c_var(cmd.dst)
    local v = self:c_value(cmd.srcs[1])
    return util.render([[
        $dst = (lua_Number) $v; ]], {
            dst = dst, v = v })
end

--
-- Control flow
--

gen_cmd["Return"] = function(self, cmd)
    local values = cmd.values
    local lines = {}
    if #values > 0 then
        assert(#values == 1, "not implemented")
        local v = self:c_value(values[1])
        table.insert(lines, util.render([[ ret = $v; ]], { v = v }))
    end
    table.insert(lines, [[ goto done; ]])
    return table.concat(lines, "\n")
end

gen_cmd["BreakIf"] = function(self, cmd)
    local x = self:c_value(cmd.condition)
    return (util.render([[ if ($x) break; ]], { x = x }))
end

gen_cmd["If"] = function(self, cmd)
    local condition = self:c_value(cmd.condition)
    local then_ = self:generate_cmds(cmd.then_)
    local else_ = self:generate_cmds(cmd.else_)
    return (util.render([[
        if ($condition) {
            ${then_}
        } else {
            ${else_}
        } ]], {
            condition = condition,
            then_ = then_,
            else_ = else_,
        }))
end

gen_cmd["Loop"] = function(self, cmd)
    local body = self:generate_cmds(cmd.cmds)
    return (util.render([[
        while (1) {
            ${body}
        } ]], {
            body = body
        }))
end

local for_counter = 0
gen_cmd["For"] = function(self, cmd)
    local typ = self.func.vars[cmd.loop_var].typ

    -- Use a unique name for the loop variables, to avoid Wshaadow warning
    for_counter = for_counter + 1
    local start = string.format("start%02d", for_counter)
    local limit = string.format("limit%02d", for_counter)
    local step  = string.format("step%02d", for_counter)

    local initialize = util.render(
        [[$ctyp $start = $startv, $limit = $limitv, $step = $stepv]], {
            ctyp = ctype(typ),
            start = start, limit = limit, step = step,
            startv = self:c_value(cmd.start),
            limitv = self:c_value(cmd.limit),
            stepv  = self:c_value(cmd.step),
        })

    local condition = util.render(
        [[($step >= 0 ? $start <= $limit : $start >= $limit)]], {
            start = start, limit = limit, step = step
        })

    local update_tmpl
    if     typ._tag == "types.T.Integer" then
        update_tmpl = [[ $start = intop(+, $start, $step) ]]
    elseif typ._tag == "types.T.Float" then
        update_tmpl = [[ $start = $start + $step ]]
    else
        error("impossible")
    end

    local update = util.render(update_tmpl, {
        start = start, limit = limit, step = step
    })

    local body = self:generate_cmds(cmd.body)

    return (util.render([[
        for(
            ${initialize};
            ${condition};
            ${update}
        ){
            $loopvar = $start;
            ${body}
        } ]], {
            loopvar = self:c_var(cmd.loop_var),
            start = start,
            initialize = initialize,
            condition = condition,
            update = update,
            body = body,
        }))
end

function Coder:generate_cmds(cmds)
    local out = {}
    for _, cmd in ipairs(cmds) do
        local name = assert(string.match(cmd._tag, "^ir%.Cmd%.(.*)$"))
        local f = assert(gen_cmd[name], "impossible")
        table.insert(out, f(self, cmd))
    end
    return table.concat(out, "\n")
end

--
-- # Luaopen function
--

function Coder:generate_luaopen_function()

    local n_func = 0
    local body = {}
    for _, f_id in ipairs(self.module.exports) do
        local func = self.module.functions[f_id]
        table.insert(body, util.render([[
            lua_pushstring(L, ${name});
            lua_pushcclosure(L, ${lua_entry_point}, ${nupv});
            lua_settable(L, export_table_index);
        ]], {
            name = C.string(func.name),
            lua_entry_point = self:lua_entry_point_name(f_id),
            nupv = C.integer(0),
        }))
    end

    return (util.render([[
        int ${name}(lua_State *L)
        {
            lua_createtable(L, 0, ${n_func});
            int export_table_index = lua_gettop(L);

            ${body}

            lua_pushvalue(L, export_table_index);
            return 1;
        }
    ]], {
        name = "luaopen_" .. self.modname,
        n_func = C.integer(n_func),
        body = table.concat(body, "\n"),
    }))
end

-- Done

local function section_comment(msg)
    local ruler = string.rep("-", #msg)
    local lines = {}
    table.insert(lines, "")
    table.insert(lines, "/* " .. ruler .. " */")
    table.insert(lines, "/* " .. msg   .. " */")
    table.insert(lines, "/* " .. ruler .. " */")
    table.insert(lines, "")
    return table.concat(lines, "\n")
end


function Coder:generate_module()

    local out = {}

    table.insert(out, [[
        /* This file was generated by the Pallene compiler. Do not edit by hand" */
        /* Indentation and formatting courtesy of pallene/C.lua */
    ]])

    table.insert(out, section_comment("C Headers"))
    table.insert(out, self:generate_headers())


    table.insert(out, section_comment("Function Prototypes"))
    for f_id = 1, #self.module.functions do
        table.insert(out, self:pallene_entry_point_declaration(f_id) .. ";")
    end

    table.insert(out, section_comment("Function Implementations"))
    for f_id = 1, #self.module.functions do
        table.insert(out, self:pallene_entry_point_definition(f_id))
    end

    table.insert(out, section_comment("Exports"))
    for f_id = 1, #self.module.functions do
        table.insert(out, self:lua_entry_point_definition(f_id))
    end
    table.insert(out, self:generate_luaopen_function())

    return C.reformat(table.concat(out, "\n"))
end


return coder
