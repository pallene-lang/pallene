local coder = {}

local types = require("titan-compiler.types")

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

local function setslot(t, s, c)
    local tmpl
    if types.equals(t, types.Integer) then tmpl = "setivalue(%s, %s);"
    elseif types.equals(t, types.Float) then tmpl = "setfltvalue(%s, %s);"
    elseif types.equals(t, types.Boolean) then tmpl = "setbvalue(%s, %s);"
    elseif types.equals(t, types.Nil) then tmpl = "setnilvalue(%s);"
    elseif types.equals(t, types.String) then tmpl = "setsvalue(%s, %s);"
    elseif types.has_tag(t, "Array") then tmpl = "sethvalue(%s, %s);"
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

local function pushd(ctx)
    table.insert(ctx.dstack, ctx.depth)
end

local function popd(ctx)
    local depth = table.remove(ctx.dstack)
    local delta = ctx.depth - depth
    ctx.depth = depth
    if delta > 0 then
        return string.format([[
            lua_lock(L);
            L->top -= %d;
            lua_unlock(L);
        ]], delta)
    else
        return nil
    end
end

local function getslot(ctx)
    ctx.depth = ctx.depth + 1
    if ctx.depth > ctx.nslots then ctx.nslots = ctx.depth end
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
    table.insert(stats, popd(ctx))
    return "    {\n    " .. table.concat(stats, "\n    ") .. "\n    }"
end

local function codewhile(ctx, node)
    pushd(ctx)
    local cstats, cexp = codeexp(ctx, node.condition)
    local cblk = codestat(ctx, node.block)
    local adjust = popd(ctx) or ""
    return string.format([[
        {
            while(1) {
                %s
                if(!(%s)) {
                    %s
                    break;
                }
                %s
                %s
            }
        }
    ]], cstats, cexp, adjust, cblk, adjust)
end

local function coderepeat(ctx, node)
    pushd(ctx)
    local cstats, cexp = codeexp(ctx, node.condition)
    local cblk = codestat(ctx, node.block)
    local adjust = popd(ctx) or ""
    return string.format([[
        {
            while(1) {
                %s
                %s
                if(%s) {
                    %s
                    break;
                }
                %s
            }
        }
    ]], cblk, cstats, cexp, adjust, adjust)
end

local function codeif(ctx, node, idx)
    idx = idx or 1
    local cstats, cexp, cthn, cels
    pushd(ctx)
    if idx == #node.thens then -- last condition
        cstats, cexp = codeexp(ctx, node.thens[idx].condition)
        cthn = codestat(ctx, node.thens[idx].block)
        cels = node.elsestat and "else " .. codestat(ctx, node.elsestat) or ""
    else
        cstats, cexp = codeexp(ctx, node.thens[idx].condition)
        cthn = codestat(ctx, node.thens[idx].block)
        cels = codeif(ctx, node, idx + 1)
    end
    local adjust = popd(ctx) or ""
    return string.format([[
        {
            %s
            if(%s) {
                %s
            } %s
            %s
        }
    ]], cstats, cexp, cthn, cels, adjust)
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
            lua_Integer _forfin = %s;
        ]], cfstats, cfexp)
    else
        cstart = string.format([[
            %s
            lua_Number _forstart = %s;
        ]], csstats, csexp)
        cfinish = string.format([[
            %s
            lua_Number _forfin = %s;
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
            local cistats, ciexp = codeexp(exp, node.inc)
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
            ccmp = "0 < _forstep ? (" .. node.decl._cvar " <= _forlimit) : (_forlimit <= " .. node.decl._cvar .. ")"
        end
    else
        if types.equals(node.decl._type, types.Integer) then
            cstep = "node.decl._cvar = l_castU2S(l_castS2U(" .. node.decl._cvar .. ") + 1)"
        else
            cstep = node.decl._cvar .. "+= 1.0"
        end
        ccmp = node.decl._cvar .. " <= _forlimit"
    end
    local cblock = codestat(ctx, node.block)
    local adjust = popd(ctx) or ""
    return string.format([[
        {
            %s
            %s
            %s
            for(%s = _forstart; %s; %s) %s
            %s
        }
    ]], cstart, cfinish, cinc, cdecl, ccmp, cstep, cblock, adjust)
end

local function codeassignment(ctx, node)
    -- has to generate different code if lvar is just a variable
    -- or an array indexing.
    local tag = node.var._tag
    if tag == "Var_Name" then
        pushd(ctx)
        local cstats, cexp = codeexp(ctx, node.exp)
        local cset = ""
        if types.is_gc(node.var._type) then
            cset = string.format([[
                /* update slot */
                lua_lock(L);
                %s
                lua_unlock(L);
            ]], setslot(node.var._type, node.var.decl._slot, node.var.decl._cvar))
        end
        local adjust = popd(ctx) or ""
        return string.format([[
            {
                %s
                %s = %s;
                %s
                %s
            }
        ]], cstats, node.var.decl._cvar, cexp, cset, adjust)
    elseif tag == "Var_Index" then
        local arr = node.var.exp1
        local idx = node.var.exp2
        pushd(ctx)
        local castats, caexp = codeexp(ctx, arr)
        local cistats, ciexp = codeexp(ctx, idx)
        local cstats, cexp = codeexp(ctx, node.exp)
        local adjust = popd(ctx) or ""
        local cset
        if types.is_gc(arr._type.elem) then
            -- write barrier
            cset = string.format([[
                TValue _vv; %s
                setobj2t(L, _slot, &_vv);
                luaC_barrierback(L, _t, &_vv);
            ]], setslot(arr._type.elem, "&_vv", cexp))
        else
            cset = setslot(arr._type.elem, "_slot", cexp)
        end
        return string.format([[
            {
                %s
                %s
                %s
                Table *_t = %s;
                lua_Integer _k = %s;
                unsigned int _actual_i = l_castS2U(_k) - 1;
                unsigned int _asize = t->sizearray;
                if (_actual_i < _asize) {
                    TValue *_slot = &t->array[_actual_i];
                    %s
                } else if (_actual_i < 2*_asize) {
                    unsigned int _hsize = sizenode(_t);
                    luaH_resize(L, _t, 2*_asize, _hsize);
                    TValue *_slot = &_t->array[_actual_i];
                    %s
                } else {
                    TValue *_slot = (TValue *)luaH_getint(_t, _k);
                    TValue _vk; setivalue(&_vk, _k);
                    if (_slot == luaO_nilobject)  /* no previous entry? */
                        _slot = luaH_newkey(L, _t, &_vk);  /* create one */
                    %s
                }
                %s
            }
        ]], castats, cistats, cstats, caexp, ciexp, cset, cset, cset, adjust)
    else
        error("invalid tag for lvalue of assignment: " .. tag)
    end
end

local function codecall(ctx, node)
end

local function codereturn(ctx, node)
    local cstats, cexp = codeexp(ctx, node.exp)
    if types.equals(node._type, types.String) then
        return cstats .. "\n    " .. string.format([[
            {
                TString *ret = %s;
                lua_lock(L);
                setsvalue(L, _retslot, ret);
                lua_unlock(L);
                return ret;
            }
        ]], cexp)
    elseif types.has_tag(node._type, "Array") then
        return cstats .. "\n    " .. string.format([[
            {
                Table *ret = %s;
                lua_lock(L);
                sethvalue(L, _retslot, ret);
                lua_unlock(L);
                return ret;
            }
        ]], cexp)
    else
        return cstats .. "\n    return " .. cexp .. ";"
    end
end

function codestat(ctx, node)
    local tag = node._tag
    if tag == "Stat_Decl" then
        local cstats, cexp = codeexp(ctx, node.exp)
        -- TODO: generate code for node.decl
        -- TODO: store cexp into variable (and maybe slot) for node.decl
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
        local cstats, cexp = codecall(ctx, node)
        -- TODO: pop stack if return type is GC
        return cstats .. "\n" .. cexp .. ";"
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
    return "", node.decl._cvar
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
end

local function codeunaryop(ctx, node)
    local op = node.op
    if op == "not" then
    elseif op == "#" then
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
    elseif op == "or" then
    elseif op == "^" then
    elseif op == ".." then
    else
        local lstats, lcode = codeexp(ctx, node.lhs)
        local rstats, rcode = codeexp(ctx, node.rhs)
        return lstats .. rstats, "(" .. lcode .. op .. rcode .. ")"
    end
end

function codeexp(ctx, node)
    local tag = node._tag
    if tag == "Var_Name" or
       tag == "Var_Index" then
        return codevar(ctx, node)
    elseif tag == "Exp_Nil" or
         tag == "Exp_Bool" or
         tag == "Exp_Integer" or
         tag == "Exp_Float" or
         tag == "Exp_String" then
        return codevalue(ctx, node)
    elseif tag == "Exp_Table" then
        return codetable(ctx, node)
    elseif tag == "Exp_Var" then
        return codevar(ctx, node)
    elseif tag == "Exp_Unop" then
        return codeunaryop(ctx, node)
    elseif tag == "Exp_Binop" then
        return codebinaryop(ctx, node)
    elseif tag == "Exp_Call" then
        return codecall(ctx, node)
    else
        error("code generation not implemented for node " .. tag)
    end
end

-- Titan calling convention:
--   first parameter is a lua_State*, other parameters
--   get the other arguments, with each being its actual
--   native type. Garbage-collectable arguments also need
--   to be pushed to the Lua stack by the *caller*. The
--   function returns its first return value directly.
--   If it is a gc-able value it must also be pushed to
--   the Lua stack, and must be the only value pushed
--   to the Lua stack when the function returns.
local function codefuncdec(tlcontext, node)
    local ctx = newcontext()
    if types.is_gc(node._type.ret) then
        ctx.nslots = 1
    end
    local cparams = {}
    for i, param in ipairs(node.params) do
        param._cvar = "_param_" .. param.name
        table.insert(cparams, ctype(param._type) .. " " .. param._cvar)
    end
    local stats = {}
    local body = codestat(ctx, node.block)
    local nslots = ctx.nslots
    table.insert(stats, string.format([[
        /* function preamble: reserve needed stack space */
        lua_lock(L);
        if (L->stack_last - L->top > %d) {
            if (L->ci->top < L->top + n) L->ci->top = L->top + n;
            lua_unlock(L);
        } else {
            lua_unlock(L);
            lua_checkstack(L, %d);
        }
    ]], nslots, nslots))
    if types.is_gc(node._type.ret) then
        table.insert(stats, [[
            /* reserve slot for return value */
            lua_lock(L);
            setnilvalue(L->top);
            Value *_retslot = L->top;
            api_incr_top(L);
            lua_unlock(L);
        ]])
    end
    table.insert(stats, body)
    if nslots > 1 then
        table.insert(stats, string.format([[
            lua_lock(L);
            L->top -= %d;
            lua_unlock(L);
        ]], nslots - 1))
    end
    table.insert(cparams, 1, "lua_State *L")
    node._body = string.format([[
    static %s %s_titan(%s) {
        %s
    }]], ctype(node._type.ret), node.name, table.concat(cparams, ", "), table.concat(stats, "\n    "))
end

local function codedecl(islocal, decl, value)
end

local function codevardec(node)
    codedecl(node.islocal, node.decl, node.value)
end

function coder.generate(ast)
    local tlcontext = {
        funcs = {},
        vars = {}
    }

    local out = {}
    for _, node in pairs(ast) do
        if not node._ignore then
            local tag = node._tag
            if tag == "TopLevel_Func" then
                codefuncdec(tlcontext, node)
                table.insert(out, node._body)
            elseif tag == "TopLevel_Var" then
                local vardec = codevardec(tlcontext, node)
                table.insert(out, vardec)
            else
                error("code generation not implemented for node " .. tag)
            end
        end
    end
    return table.concat(out, "\n")
end

return coder
