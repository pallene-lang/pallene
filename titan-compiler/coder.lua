local types = require "titan-compiler.types"

local coder = {}

local codeexp, codestat

local function node2literal(node)
    local tag = node._tag
    if tag == "Exp_Integer" or tag == "Exp_Float" then
        return tonumber(node.value)
    elseif tag == "Exp_Unop" and node.op == "-" then
        local lexp = node2literal(node.exp)
        return lexp and -lexp
    else
        return nil
    end
end

local function checktype(t, s, lin)
    local tag
    if types.equals(t, types.Integer) then tag = "integer"
    elseif types.equals(t, types.Float) then tag = "float"
    elseif types.equals(t, types.Boolean) then tag = "boolean"
    elseif types.equals(t, types.Nil) then tag = "nil"
    elseif types.equals(t, types.String) then tag = "string"
    elseif types.has_tag(t, "Array") then tag = "table"
    else
        error("invalid type " .. types.tostring(t))
    end
    return string.format([[
        if(!ttis%s(%s)) luaL_error(L, "type error at line %d, expected %s but found %%s", lua_typename(L, ttnov(%s)));
    ]], tag, s, lin, tag, s)
end

local function getslot(t, c, s)
    local tmpl
    if types.equals(t, types.Integer) then tmpl = "%s = ivalue(%s);"
    elseif types.equals(t, types.Float) then tmpl = "%s = fltvalue(%s);"
    elseif types.equals(t, types.Boolean) then tmpl = "%s = bvalue(%s);"
    elseif types.equals(t, types.Nil) then tmpl = "%s = 0;"
    elseif types.equals(t, types.String) then tmpl = "%s = svalue(%s);"
    elseif types.has_tag(t, "Array") then tmpl = "%s = hvalue(%s);"
    else
        error("invalid type " .. types.tostring(t))
    end
    return string.format(tmpl, c, s)
end

local function setslot(t, s, c)
    local tmpl
    if types.equals(t, types.Integer) then tmpl = "setivalue(%s, %s);"
    elseif types.equals(t, types.Float) then tmpl = "setfltvalue(%s, %s);"
    elseif types.equals(t, types.Boolean) then tmpl = "setbvalue(%s, %s);"
    elseif types.equals(t, types.Nil) then tmpl = "setnilvalue(%s); ((void)%s);"
    elseif types.equals(t, types.String) then tmpl = "setsvalue(L, %s, %s);"
    elseif types.has_tag(t, "Array") then tmpl = "sethvalue(L, %s, %s);"
    else
        error("invalid type " .. types.tostring(t))
    end
    return string.format(tmpl, s, c)
end

local function ctype(t)
    if types.equals(t, types.Integer) then return "lua_Integer"
    elseif types.equals(t, types.Float) then return "lua_Number"
    elseif types.equals(t, types.Boolean) then return "int"
    elseif types.equals(t, types.Nil) then return "int"
    elseif types.equals(t, types.String) then return "TString*"
    elseif types.has_tag(t, "Array") then return "Table*"
    else error("invalid type " .. types.tostring(t))
    end
end

-- creates a new code generation context for a function
local function newcontext()
    return {
        tmp = 1,    -- next temporary index (for generating temporary names)
        nslots = 0, -- number of slots needed by function
        depth = 0,  -- current stack depth
        dstack = {} -- stack of stack depths
    }
end

local function newslot(ctx, name)
    local sdepth = ctx.depth
    ctx.depth = ctx.depth + 1
    if ctx.depth > ctx.nslots then ctx.nslots = ctx.depth end
    return string.format([[
        TValue *%s = _base + %d;
    ]], name, sdepth)
end

local function newtmp(ctx, typ, isgc)
    local tmp = ctx.tmp
    ctx.tmp = ctx.tmp + 1
    if isgc then
        return newslot(ctx, "_tmp_" .. tmp .. "_slot") .. string.format([[
            %s _tmp_%d;
        ]], ctype(typ), tmp), "_tmp_" .. tmp, "_tmp_" .. tmp .. "_slot"
    else
        return string.format([[
            %s _tmp_%d;
        ]], ctype(typ), tmp), "_tmp_" .. tmp
    end
end

local function pushd(ctx)
    table.insert(ctx.dstack, ctx.depth)
end

local function popd(ctx)
    ctx.depth = table.remove(ctx.dstack)
end

-- All the code generation functions for STATEMENTS take
-- the function context and the AST node and return the
-- generated C code for the statement, as a string

local function codeblock(ctx, node)
    local stats = {}
    pushd(ctx)
    for _, stat in ipairs(node.stats) do
        table.insert(stats, codestat(ctx, stat))
    end
    popd(ctx)
    return "    {\n    " .. table.concat(stats, "\n    ") .. "\n    }"
end

local function codewhile(ctx, node)
    pushd(ctx)
    local cstats, cexp = codeexp(ctx, node.condition)
    local cblk = codestat(ctx, node.block)
    popd(ctx)
    local restoretop = "" -- FIXME
    return string.format([[
        while(1) {
            %s
            if(!(%s)) {
                %s
                break;
            }
            %s
        }
    ]], cstats, cexp, restoretop, cblk)
end

local function coderepeat(ctx, node)
    pushd(ctx)
    local cstats, cexp = codeexp(ctx, node.condition)
    local cblk = codestat(ctx, node.block)
    popd(ctx)
    return string.format([[
        while(1) {
            %s
            if(%s) {
                break;
            }
        }
    ]], cblk, cstats, cexp)
end

local function codeif(ctx, node, idx)
    idx = idx or 1
    local cstats, cexp, cthn, cels
    if idx == #node.thens then -- last condition
        cstats, cexp = codeexp(ctx, node.thens[idx].condition)
        cthn = codestat(ctx, node.thens[idx].block)
        cels = node.elsestat and "else " .. codestat(ctx, node.elsestat) or ""
    else
        cstats, cexp = codeexp(ctx, node.thens[idx].condition)
        cthn = codestat(ctx, node.thens[idx].block)
        cels = codeif(ctx, node, idx + 1)
    end
    return string.format([[
        {
            %s
            if(%s) {
                %s
            } %s
        }
    ]], cstats, cexp, cthn, cels)
end

local function codefor(ctx, node)
    pushd(ctx)
    node.decl._cvar = "_local_" .. node.decl.name
    local cdecl = ctype(node.decl._type) .. " " .. node.decl._cvar
    local csstats, csexp = codeexp(ctx, node.start)
    local cfstats, cfexp = codeexp(ctx, node.finish)
    local cinc = ""
    local cstart, cfinish, cstep, ccmp
    if types.equals(node.decl._type, types.Integer) then
        cstart = string.format([[
            %s
            lua_Integer _forstart = %s;
        ]], csstats, csexp)
        cfinish = string.format([[
            %s
            lua_Integer _forlimit = %s;
        ]], cfstats, cfexp)
    else
        cstart = string.format([[
            %s
            lua_Number _forstart = %s;
        ]], csstats, csexp)
        cfinish = string.format([[
            %s
            lua_Number _forlimit = %s;
        ]], cfstats, cfexp)
    end
    if node.inc then
        local ilit = node2literal(node.inc)
        if ilit then
            if ilit > 0 then
                if types.equals(node.decl._type, types.Integer) then
                    cstep = node.decl._cvar .. " = l_castU2S(l_castS2U(" .. node.decl._cvar .. ") + " .. tostring(ilit) .. ")"
                else
                    cstep = node.decl._cvar .. " += " .. tostring(ilit)
                end
                ccmp = node.decl._cvar .. " <= _forlimit"
            else
                if types.equals(node.decl._type, types.Integer) then
                    cstep = node.decl._cvar .. " = l_castU2S(l_castS2U(" .. node.decl._cvar .. ") - " .. tostring(-ilit) .. ")"
                else
                    cstep = node.decl._cvar .. " -= " .. tostring(ilit)
                end
                ccmp = "_forlimit <= " .. node.decl._cvar
            end
        else
            local cistats, ciexp = codeexp(ctx, node.inc)
            if types.equals(node.decl._type, types.Integer) then
                cinc = string.format([[
                    %s
                    lua_Integer _forstep = %s;
                ]], cistats, ciexp)
                cstep = node.decl._cvar .. " = l_castU2S(l_castS2U(" .. node.decl._cvar .. ") + l_castS2U(_forstep))"
            else
                cinc = string.format([[
                    %s
                    lua_Number _forstep = %s;
                ]], cistats, ciexp)
                cstep = node.decl._cvar .. " += _forstep"
            end
            ccmp = "0 < _forstep ? (" .. node.decl._cvar .. " <= _forlimit) : (_forlimit <= " .. node.decl._cvar .. ")"
        end
    else
        if types.equals(node.decl._type, types.Integer) then
            cstep = node.decl._cvar .. " = l_castU2S(l_castS2U(" .. node.decl._cvar .. ") + 1)"
        else
            cstep = node.decl._cvar .. "+= 1.0"
        end
        ccmp = node.decl._cvar .. " <= _forlimit"
    end
    local cblock = codestat(ctx, node.block)
    popd(ctx)
    return string.format([[
        {
            %s
            %s
            %s
            for(%s = _forstart; %s; %s) {
                %s
            }
        }
    ]], cstart, cfinish, cinc, cdecl, ccmp, cstep, cblock)
end

local function codeassignment(ctx, node)
    -- has to generate different code if lvar is just a variable
    -- or an array indexing.
    local vtag = node.var._tag
    if vtag == "Var_Name" then
        local cstats, cexp = codeexp(ctx, node.exp)
        local cset = ""
        if types.is_gc(node.var._type) then
            cset = string.format([[
                /* update slot */
                %s
            ]], setslot(node.var._type, node.var._decl._slot, node.var._decl._cvar))
        end
        return string.format([[
            {
                %s
                %s = %s;
                %s
            }
        ]], cstats, node.var._decl._cvar, cexp, cset)
    elseif vtag == "Var_Index" then
        local arr = node.var.exp1
        local idx = node.var.exp2
        local etype = node.exp._type
        local castats, caexp = codeexp(ctx, arr)
        local cistats, ciexp = codeexp(ctx, idx)
        local cstats, cexp = codeexp(ctx, node.exp)
        local cset
        if types.is_gc(arr._type.elem) then
            -- write barrier
            cset = string.format([[
                TValue _vv; %s
                setobj2t(L, _slot, &_vv);
                luaC_barrierback(L, _t, &_vv);
            ]], setslot(etype, "&_vv", cexp))
        else
            cset = setslot(etype, "_slot", cexp)
        end
        return string.format([[
            {
                %s
                %s
                %s
                Table *_t = %s;
                lua_Integer _k = %s;
                unsigned int _actual_i = l_castS2U(_k) - 1;
                unsigned int _asize = _t->sizearray;
                if (_actual_i < _asize) {
                    TValue *_slot = &_t->array[_actual_i];
                    %s
                } else if (_actual_i < 2*_asize) {
                    unsigned int _hsize = sizenode(_t);
                    luaH_resize(L, _t, 2*_asize, _hsize);
                    TValue *_slot = &_t->array[_actual_i];
                    %s
                } else {
                    TValue *_slot = (TValue *)luaH_getint(_t, _k);
                    TValue _vk; setivalue(&_vk, _k);
                    if (_slot == luaO_nilobject)    /* no previous entry? */
                            _slot = luaH_newkey(L, _t, &_vk);    /* create one */
                    %s
                }
            }
        ]], castats, cistats, cstats, caexp, ciexp, cset, cset, cset)
    else
        error("invalid tag for lvalue of assignment: " .. vtag)
    end
end

local function codecall(ctx, node)
    local castats, caexps = {}, { "L" }
    for _, arg in ipairs(node.args.args) do
        local cstat, cexp = codeexp(ctx, arg)
        table.insert(castats, cstat)
        table.insert(caexps, cexp)
    end
    if types.is_gc(node._type) then
        local ctmp, tmpname, tmpslot = newtmp(ctx, node._type, true)
        return string.format([[
            %s
            %s
            %s = %s_titan(%s);
            %s;
        ]], table.concat(castats, "\n"), ctmp, tmpname, node.exp.var.name,
            table.concat(caexps, ", "), setslot(node._type, tmpslot, tmpname)), tmpname
    else
        return table.concat(castats, "\n"), node.exp.var.name .. "_titan(" .. table.concat(caexps, ", ") .. ")"
    end
end

local function codereturn(ctx, node)
    local cstats, cexp = codeexp(ctx, node.exp)
    if types.equals(node._type, types.String) then
        return string.format([[
            {
                %s
                TString *ret = %s;
                setsvalue(L, _retslot, ret);
                L->top = _retslot + 1;
                return ret;
            }
        ]], cstats, cexp)
    elseif types.has_tag(node._type, "Array") then
        return string.format([[
            {
                %s
                Table *ret = %s;
                sethvalue(L, _retslot, ret);
                L->top = _retslot + 1;
                return ret;
            }
        ]], cstats, cexp)
    else
        if ctx.nslots > 0 then
            return string.format([[
                %s
                L->top = _base;
                return %s;
            ]], cstats, cexp)
        else
            return string.format([[
                %s
                return %s;
            ]], cstats, cexp)
        end
    end
end

function codestat(ctx, node)
    local tag = node._tag
    if tag == "Stat_Decl" then
        local cstats, cexp = codeexp(ctx, node.exp)
        local typ = node.decl._type
        node.decl._cvar = "_local_" .. node.decl.name
        local cdecl = ctype(typ) .. " " .. node.decl._cvar .. ";"
        local cslot = ""
        local cset = ""
        if types.is_gc(typ) then
            node.decl._slot = "_localslot_" .. node.decl.name
            cslot = newslot(ctx, node.decl._slot);
            cset = string.format([[
                /* update slot */
                %s
            ]], setslot(typ, node.decl._slot, node.decl._cvar))
        end
        return string.format([[
            %s
            %s
            {
                %s
                %s = %s;
                %s
            }
        ]], cdecl, cslot, cstats, node.decl._cvar, cexp, cset)
    elseif tag == "Stat_Block" then
        return codeblock(ctx, node)
    elseif tag == "Stat_While" then
        return codewhile(ctx, node)
    elseif tag == "Stat_Repeat" then
        return coderepeat(ctx, node)
    elseif tag == "Stat_If" then
        return codeif(ctx, node)
    elseif tag == "Stat_For" then
        return codefor(ctx, node)
    elseif tag == "Stat_Assign" then
        return codeassignment(ctx, node)
    elseif tag == "Stat_Call" then
      local cstats, cexp = codecall(ctx, node.callexp)
      return cstats .. "\n    " .. cexp .. ";"
    elseif tag == "Stat_Return" then
        return codereturn(ctx, node)
    else
        error("code generation not implemented for node " .. tag)
    end
end

-- All the code generation functions for EXPRESSIONS return
-- preliminary C code necessary for computing the expression
-- as a string of C statements, plus the code for the expression
-- as a string with a C expression. For trivial expressions
-- the preliminary code is always the empty string

local function codevar(ctx, node)
    return "", node._decl._cvar
end

local function codevalue(ctx, node)
    local tag = node._tag
    if tag == "Exp_Nil" then
        return "", "0"
    elseif tag == "Exp_Bool" then
        return "", node.value and "1" or "0"
    elseif tag == "Exp_Integer" then
        return "", string.format("%i", node.value)
    elseif tag == "Exp_Float" then
        return "", string.format("%lf", node.value)
    elseif tag == "Exp_String" then
        -- TODO: make a constant table so we can
        -- allocate literal strings on module load time
        error("code generation for literal strings not implemented")
    else
        error("invalid tag for a literal value: " .. tag)
    end
end

local function codetable(ctx, node)
    local stats = {}
    local ctmp, tmpname, tmpslot = newtmp(ctx, node._type, true)
    local cinit = string.format([[
        %s
        %s = luaH_new(L);
        sethvalue(L, %s, %s);
    ]], ctmp, tmpname, tmpslot, tmpname)
    table.insert(stats, cinit)
    local slots = {}
    for _, exp in ipairs(node.exps) do
        local cstats, cexp = codeexp(ctx, exp)
        local ctmpe, tmpename, tmpeslot = newtmp(ctx, node._type.elem, true)
        table.insert(slots, tmpeslot)
        table.insert(stats, string.format([[
            %s
            %s
            %s = %s;
            %s
        ]], cstats, ctmpe, tmpename, cexp, setslot(node._type.elem, tmpeslot, tmpename)))
    end
    if #node.exps > 0 then
        table.insert(stats, string.format([[
        luaH_resizearray(L, %s, %d);
        ]], tmpname, #node.exps))
    end
    local cbarrier = ""
    for i, slot in ipairs(slots) do
        table.insert(stats, string.format([[
            setobj2t(L, &%s->array[%d], %s);
        ]], tmpname, i-1, slot))
        if types.is_gc(node._type.elem) then
            table.insert(stats, string.format([[
                luaC_barrierback(L, %s, %s);
            ]], tmpname, slot))
        end
    end
    return table.concat(stats, "\n"), tmpname
end

local function codeunaryop(ctx, node)
    local op = node.op
    if op == "not" then
        local estats, ecode = codeexp(ctx, node.exp)
        return estats, "!(" .. ecode .. ")"
    elseif op == "#" then
        local estats, ecode = codeexp(ctx, node.exp)
        return estats, "luaH_getn(" .. ecode .. ")"
    else
        local estats, ecode = codeexp(ctx, node.exp)
        return estats, "(" .. op .. ecode .. ")"
    end
end

local function codebinaryop(ctx, node)
    local op = node.op
    if op == "//" then op = "/" end
    if op == "~=" then op = "!=" end
    if op == "and" then
        local lstats, lcode = codeexp(ctx, node.lhs)
        if types.equals(node.lhs._type, types.Boolean) then
            local rstats, rcode = codeexp(ctx, node.rhs)
            return lstats .. rstats, "(" .. lcode .. " && " .. rcode .. ")"
        elseif types.equals(node.lhs._type, types.Nil) then
            return lstats, lcode
        else
            local rstats, rcode = codeexp(ctx, node.rhs)
            return lstats .. rstats, "(" .. lcode .. ", " .. rcode .. ")"
        end
    elseif op == "or" then
        local lstats, lcode = codeexp(ctx, node.lhs)
        if types.equals(node.lhs._type, types.Boolean) then
            local rstats, rcode = codeexp(ctx, node.rhs)
            return lstats .. rstats, "(" .. lcode .. " || " .. rcode .. ")"
        elseif types.equals(node.lhs._type, types.Nil) then
            local rstats, rcode = codeexp(ctx, node.rhs)
            return lstats .. rstats, "(" .. lcode .. ", " .. rcode .. ")"
        else
            return lstats, lcode
        end
    elseif op == "^" then
        local lstats, lcode = codeexp(ctx, node.lhs)
        local rstats, rcode = codeexp(ctx, node.rhs)
        return lstats .. rstats, "pow(" .. lcode .. ", " .. rcode .. ")"
    elseif op == ".." then
        error("concatenation not implemented")
    else
        local lstats, lcode = codeexp(ctx, node.lhs)
        local rstats, rcode = codeexp(ctx, node.rhs)
        return lstats .. rstats, "(" .. lcode .. op .. rcode .. ")"
    end
end

local function codeindex(ctx, node)
    local castats, caexp = codeexp(ctx, node.exp1)
    local cistats, ciexp = codeexp(ctx, node.exp2)
    local typ = node._type
    local ctmp, tmpname, tmpslot = newtmp(ctx, typ, types.is_gc(typ))
    local cset = ""
    local ccheck = checktype(typ, "_s", node._lin)
    local cget = getslot(typ, tmpname, "_s")
    if types.is_gc(typ) then
        cset = setslot(typ, tmpslot, tmpname)
    end
    local stats = string.format([[
        %s
        {
            %s
            %s
            Table *_t = %s;
            lua_Integer _k = %s;

            unsigned int _actual_i = l_castS2U(_k) - 1;

            const TValue *_s;
            if (_actual_i < _t->sizearray) {
                    _s = &_t->array[_actual_i];
            } else {
                    _s = luaH_getint(_t, _k);
            }

            %s
            %s
            %s
    }]], ctmp, castats, cistats, caexp, ciexp, ccheck, cget, cset)
    return stats, tmpname
end

function codeexp(ctx, node)
        local tag = node._tag
        if tag == "Var_Name" then
            return codevar(ctx, node)
        elseif tag == "Var_Index" then
            return codeindex(ctx, node)
        elseif tag == "Exp_Nil" or
                 tag == "Exp_Bool" or
                 tag == "Exp_Integer" or
                 tag == "Exp_Float" or
                 tag == "Exp_String" then
                return codevalue(ctx, node)
        elseif tag == "Exp_Table" then
                return codetable(ctx, node)
        elseif tag == "Exp_Var" then
            return codeexp(ctx, node.var)
        elseif tag == "Exp_Unop" then
                return codeunaryop(ctx, node)
        elseif tag == "Exp_Binop" then
                return codebinaryop(ctx, node)
        elseif tag == "Exp_Call" then
            return codecall(ctx, node)
        elseif tag == "Exp_ToFloat" then
            local cstat, cexp = codeexp(ctx, node.exp)
            return cstat, "((lua_Number)" .. cexp .. ")"
        elseif tag == "Exp_ToInt" then
            local cstat, cexp = codeexp(ctx, node.exp)
            local ctmp1, tmpname1 = newtmp(ctx, types.Float)
            local ctmp2, tmpname2 = newtmp(ctx, types.Float)
            local ctmp3, tmpname3 = newtmp(ctx, types.Integer)
            local cfloor = string.format([[
                %s
                %s
                %s
                %s
                %s = fltvalue(%s);
                %s = l_floor(%s);
                if (%s != %s) %s = 0; else lua_numbertointeger(%s, &%s);
            ]], cstat, ctmp1, ctmp2, ctmp3, tmpname1, cexp, tmpname2, tmpname1, tmpname1,
                tmpname2, tmpname3, tmpname2, tmpname3)
            return cfloor, tmpname3
        elseif tag == "Exp_ToStr" then
            error("code generation for coercion to string not implemented")
        else
                error("code generation not implemented for node " .. tag)
        end
end

-- Titan calling convention:
--     first parameter is a lua_State*, other parameters
--     get the other arguments, with each being its actual
--     native type. Garbage-collectable arguments also need
--     to be pushed to the Lua stack by the *caller*. The
--     function returns its first return value directly.
--     If it is a gc-able value it must also be pushed to
--     the Lua stack, and must be the only value pushed
--     to the Lua stack when the function returns.
local function codefuncdec(tlcontext, node)
    local ctx = newcontext()
    local stats = {}
    if types.is_gc(node._type.ret) then
        newslot(ctx, "_retslot");
    end
    local cparams = { "lua_State *L" }
    for i, param in ipairs(node.params) do
        param._cvar = "_param_" .. param.name
        if types.is_gc(param._type) and param._assigned then
            param._slot = "_paramslot_" .. param.name
            table.insert(stats, newslot(ctx, param._slot))
        end
        table.insert(cparams, ctype(param._type) .. " " .. param._cvar)
    end
    local body = codestat(ctx, node.block)
    local nslots = ctx.nslots
    if nslots > 0 then
        table.insert(stats, 1, string.format([[
        /* function preamble: reserve needed stack space */
        if (L->stack_last - L->top > %d) {
            if (L->ci->top < L->top + %d) L->ci->top = L->top + %d;
        } else {
            lua_checkstack(L, %d);
        }
        TValue *_base = L->top;
        L->top += %d;
        for(TValue *_s = L->top - 1; _base <= _s; _s--)
            setnilvalue(_s);
        ]], nslots, nslots, nslots, nslots, nslots))
    end
    if types.is_gc(node._type.ret) then
        table.insert(stats, [[
        /* reserve slot for return value */
        TValue *_retslot = _base;]])
    end
    table.insert(stats, body)
    if types.equals(node._type.ret, types.Nil) then
        if nslots > 0 then
            table.insert(stats, [[
            L->top = _base;
            return 0;]])
        else
            table.insert(stats, "        return 0;")
        end
    end
    node._body = string.format([[
    static %s %s_titan(%s) {
        %s
    }]], ctype(node._type.ret), node.name, table.concat(cparams, ", "), table.concat(stats, "\n        "))
    -- generate Lua entry point
    local stats = {}
    local pnames = { "L" }
    for i, param in ipairs(node.params) do
        table.insert(pnames, param._cvar)
        table.insert(stats, checktype(param._type, "(func+ " .. i .. ")", node._lin))
        table.insert(stats, getslot(param._type,
            ctype(param._type) .. " " .. param._cvar,
            "(func+ " .. i .. ")"))
    end
    table.insert(stats, string.format([[
        %s res = %s_titan(%s);
        %s
        api_incr_top(L);
        return 1;
    ]], ctype(node._type.ret), node.name, table.concat(pnames, ", "),
            setslot(node._type.ret, "L->top", "res")))
    node._luabody = string.format([[
    static int %s_lua(lua_State *L) {
        TValue *func = L->ci->func;
        if((L->top - func - 1) != %d) luaL_error(L, "calling Titan function %s with %%d arguments, but expected %d", L->top - func - 1);
        %s
    }]], node.name, #node.params, node.name, #node.params, table.concat(stats, "\n"))
end

local function codevardec(node)
    -- TODO: generate code for global variables
    error("code generation for global variables is not implemented")
end

local preamble = [[
#include "lauxlib.h"
#include "lualib.h"

#include "lapi.h"
#include "lgc.h"
#include "ltable.h"
#include "lvm.h"

#include "lobject.h"
]]

local postamble = [[
int luaopen_%s(lua_State *L) {
    lua_newtable(L);
    %s
    return 1;
}
]]

function coder.generate(modname, ast)
    local tlcontext = {
        module = modname,
    }

    local code = { preamble }
    local funcs = {}

    for _, node in pairs(ast) do
        if not node._ignore then
            local tag = node._tag
            if tag == "TopLevel_Func" then
                codefuncdec(tlcontext, node)
                table.insert(code, node._body)
                if not node.islocal then
                    table.insert(code, node._luabody)
                    table.insert(funcs, string.format([[
                        lua_pushcfunction(L, %s_lua);
                        lua_setfield(L, -2, "%s");
                    ]], node.name, node.name))
                end
            elseif tag == "TopLevel_Var" then
                codevardec(tlcontext, node)
            else
                error("code generation not implemented for node " .. tag)
            end
        end
    end

    table.insert(code, string.format(postamble, modname, table.concat(funcs, "\n")))

    return table.concat(code, "\n\n")
end

return coder
