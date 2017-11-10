local types = require "titan-compiler.types"

local coder = {}

local codeexp, codestat

-- Barebones string-based template function for generating C code.
-- Replaces $VAR placeholders in the `code` template by the corresponding
-- strings in the `substs` table.
local function output(code, substs)
    return (string.gsub(code, "$([%w_]+)", function(k)
        local v = substs[k]
        if not v then
            error("Internal compiler error: missing template variable " .. k)
        end
        return v
    end))
end

local function quotestr(s)
    s = s:gsub("\\", "\\\\")
        :gsub("\a", "\\a")
        :gsub("\b", "\\b")
        :gsub("\f", "\\f")
        :gsub("\n", "\\n")
        :gsub("\r", "\\r")
        :gsub("\t", "\\t")
        :gsub("\v", "\\v")
        :gsub("\"", "\\\"")
    return '"' .. s .. '"'
end

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

local function getslot(typ --[[:table]], dst --[[:string?]], src --[[:string]])
    dst = dst and dst .. " =" or ""
    local tmpl
    if types.equals(typ, types.Integer) then tmpl = "$DST ivalue($SRC)"
    elseif types.equals(typ, types.Float) then tmpl = "$DST fltvalue($SRC)"
    elseif types.equals(typ, types.Boolean) then tmpl = "$DST bvalue($SRC)"
    elseif types.equals(typ, types.Nil) then tmpl = "$DST 0"
    elseif types.equals(typ, types.String) then tmpl = "$DST tsvalue($SRC)"
    elseif types.has_tag(typ, "Array") then tmpl = "$DST hvalue($SRC)"
    else
        error("invalid type " .. types.tostring(typ))
    end
    return output(tmpl, { DST = dst, SRC = src })
end

local function checkandget(typ --[[:table]], cvar --[[:string]], exp --[[:string]], line --[[:number]])
    local tag
    if types.equals(typ, types.Integer) then tag = "integer"
    elseif types.equals(typ, types.Float) then
        return output([[
            if (ttisinteger($EXP)) {
                $VAR = (lua_Number)ivalue($EXP);
            } else if (ttisfloat($EXP)) {
                $VAR = fltvalue($EXP);
            } else {
                luaL_error(L, "type error at line $LINE, expected float but found %s", lua_typename(L, ttnov($EXP)));
            }
        ]], {
            EXP = exp,
            VAR = cvar,
            LINE = line,
        })
    elseif types.equals(typ, types.Boolean) then tag = "boolean"
    elseif types.equals(typ, types.Nil) then tag = "nil"
    elseif types.equals(typ, types.String) then tag = "string"
    elseif types.has_tag(typ, "Array") then tag = "table"
    else
        error("invalid type " .. types.tostring(typ))
    end
    --return getslot(typ, cvar, exp) .. ";"
    return output([[
        if(ttis$TAG($EXP)) {
            $GETSLOT;
        } else {
            luaL_error(L, "type error at line $LINE, expected $TAG but found %s", lua_typename(L, ttnov($EXP)));
        }
    ]], {
        EXP = exp,
        TAG = tag,
        GETSLOT = getslot(typ, cvar, exp),
        LINE = line,
    })
end

local function checkandset(typ --[[:table]], dst --[[:string]], src --[[:string]], line --[[:number]])
    local tag
    if types.equals(typ, types.Integer) then tag = "integer"
    elseif types.equals(typ, types.Float) then
        return output([[
            if (ttisinteger($SRC)) {
                setfltvalue($DST, ((lua_Number)ivalue($SRC)));
            } else if (ttisfloat($SRC)) {
                setobj2t(L, $DST, $SRC);
            } else {
                luaL_error(L, "type error at line $LINE, expected float but found %s", lua_typename(L, ttnov($SRC)));
            }
        ]], {
            SRC = src,
            DST = dst,
            LINE = line,
        })
    elseif types.equals(typ, types.Boolean) then tag = "boolean"
    elseif types.equals(typ, types.Nil) then tag = "nil"
    elseif types.equals(typ, types.String) then tag = "string"
    elseif types.has_tag(typ, "Array") then tag = "table"
    else
        error("invalid type " .. types.tostring(typ))
    end
    return output([[
        if (ttis$TAG($SRC)) {
            setobj2t(L, $DST, $SRC);
        } else {
            luaL_error(L, "type error at line $LINE, expected $TAG but found %s", lua_typename(L, ttnov($SRC)));
        }
    ]], {
        TAG = tag,
        SRC = src,
        DST = dst,
        LINE = line,
    })
end

local function setslot(typ --[[:table]], dst --[[:string]], src --[[:string]])
    local tmpl
    if types.equals(typ, types.Integer) then tmpl = "setivalue($DST, $SRC);"
    elseif types.equals(typ, types.Float) then tmpl = "setfltvalue($DST, $SRC);"
    elseif types.equals(typ, types.Boolean) then tmpl = "setbvalue($DST, $SRC);"
    elseif types.equals(typ, types.Nil) then tmpl = "setnilvalue($DST); ((void)$SRC);"
    elseif types.equals(typ, types.String) then tmpl = "setsvalue(L, $DST, $SRC);"
    elseif types.has_tag(typ, "Array") then tmpl = "sethvalue(L, $DST, $SRC);"
    else
        error("invalid type " .. types.tostring(typ))
    end
    return output(tmpl, { DST = dst, SRC = src })
end

local function ctype(typ --[[:table]])
    if types.equals(typ, types.Integer) then return "lua_Integer"
    elseif types.equals(typ, types.Float) then return "lua_Number"
    elseif types.equals(typ, types.Boolean) then return "int"
    elseif types.equals(typ, types.Nil) then return "int"
    elseif types.equals(typ, types.String) then return "TString*"
    elseif types.has_tag(typ, "Array") then return "Table*"
    else error("invalid type " .. types.tostring(typ))
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

local function newslot(ctx --[[:table]], name --[[:string]])
    local sdepth = ctx.depth
    ctx.depth = ctx.depth + 1
    if ctx.depth > ctx.nslots then ctx.nslots = ctx.depth end
    return output([[
    	TValue *$NAME = _base + $SDEPTH;
    ]], {
    	NAME = name,
    	SDEPTH = sdepth,
    })
end

local function newtmp(ctx --[[:table]], typ --[[:table]], isgc --[[:boolean]])
    local tmp = ctx.tmp
    ctx.tmp = ctx.tmp + 1
    local tmpname = "_tmp_" .. tmp
    if isgc then
        local slotname = "_tmp_" .. tmp .. "_slot"
        return output([[
            $NEWSLOT
            $TYPE $TMPNAME = 0;
        ]], {
            TYPE = ctype(typ),
            NEWSLOT = newslot(ctx, slotname),
            TMPNAME = tmpname,
        }), tmpname, slotname
    else
        return output([[
            $TYPE $TMPNAME = 0;
        ]], {
            TYPE = ctype(typ),
            TMPNAME = tmpname,
        }), tmpname
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
    return " {\n " .. table.concat(stats, "\n ") .. "\n }"
end

local function codewhile(ctx, node)
    pushd(ctx)
    local cstats, cexp = codeexp(ctx, node.condition, true)
    local cblk = codestat(ctx, node.block)
    popd(ctx)
    local tmpl
    if cstats == "" then
        tmpl = [[
            while($CEXP) {
                $CBLK
            }
        ]]
    else
        tmpl = [[
            while(1) {
                $CSTATS
                if(!($CEXP)) {
                    break;
                }
                $CBLK
            }
        ]]
    end
    return output(tmpl, {
        CSTATS = cstats,
        CEXP = cexp,
        CBLK = cblk,
    })
end

local function coderepeat(ctx, node)
    pushd(ctx)
    local cstats, cexp = codeexp(ctx, node.condition, true)
    local cblk = codestat(ctx, node.block)
    popd(ctx)
    return output([[
        while(1) {
            $CBLK
            $CSTATS
            if($CEXP) {
                break;
            }
        }
    ]], {
        CBLK = cblk,
        CSTATS = cstats,
        CEXP = cexp
    })
end

local function codeif(ctx, node, idx)
    idx = idx or 1
    local cstats, cexp, cthn, cels
    if idx == #node.thens then -- last condition
        cstats, cexp = codeexp(ctx, node.thens[idx].condition, true)
        cthn = codestat(ctx, node.thens[idx].block)
        cels = node.elsestat and "else " .. codestat(ctx, node.elsestat):match("^[ \t]*(.*)") or ""
    else
        cstats, cexp = codeexp(ctx, node.thens[idx].condition, true)
        cthn = codestat(ctx, node.thens[idx].block)
        cels = "else " .. codeif(ctx, node, idx + 1):match("^[ \t]*(.*)")
    end
    return output([[
        {
            $CSTATS
            if($CEXP) {
                $CTHN
            } $CELS
        }
    ]], {
        CSTATS = cstats,
        CEXP = cexp,
        CTHN = cthn,
        CELS = cels
    })
end

local function codefor(ctx, node)
    pushd(ctx)
    node.decl._cvar = "_local_" .. node.decl.name
    local cdecl = ctype(node.decl._type) .. " " .. node.decl._cvar
    local csstats, csexp = codeexp(ctx, node.start)
    local cfstats, cfexp = codeexp(ctx, node.finish)
    local cinc = ""
    local cvtyp
    if types.equals(node.decl._type, types.Integer) then
        cvtyp = "lua_Integer"
    else
        cvtyp = "lua_Number"
    end
    local cstart = output([[
        $CSSTATS
        $CVTYP _forstart = $CSEXP;
    ]], {
        CSSTATS = csstats,
        CSEXP = csexp,
        CVTYP = cvtyp,
    })
    local cfinish = output([[
        $CFSTATS
        $CVTYP _forlimit = $CFEXP;
    ]], {
        CFSTATS = cfstats,
        CFEXP = cfexp,
        CVTYP = cvtyp,
    })
    local cstep, ccmp
    local subs = {
        CVAR = node.decl._cvar,
    }
    if node.inc then
        local ilit = node2literal(node.inc)
        if ilit then
            if ilit > 0 then
                subs.ILIT = ilit
                local tmpl
                if types.equals(node.decl._type, types.Integer) then
                    tmpl = "$CVAR = l_castU2S(l_castS2U($CVAR) + $ILIT)"
                else
                    tmpl = "$CVAR += $ILIT"
                end
                cstep = output(tmpl, subs)
                ccmp = output("$CVAR <= _forlimit", subs)
            else
                subs.NEGILIT = ilit and -ilit
                if types.equals(node.decl._type, types.Integer) then
                    cstep = output("$CVAR = l_castU2S(l_castS2U($CVAR) - $NEGILIT)", subs)
                else
                    cstep = output("$CVAR -= $ILIT", subs)
                end
                ccmp = output("_forlimit <= $CVAR", subs)
            end
        else
            local cistats, ciexp = codeexp(ctx, node.inc)
            cinc = output([[
                $CISTATS
                $CVTYP _forstep = $CIEXP;
            ]], {
                CISTATS = cistats,
                CIEXP = ciexp,
                CVTYP = cvtyp,
            })
            local tmpl
            if types.equals(node.decl._type, types.Integer) then
                tmpl = "$CVAR = l_castU2S(l_castS2U($CVAR) + l_castS2U(_forstep))"
            else
                tmpl = "$CVAR += _forstep"
            end
            cstep = output(tmpl, subs)
            ccmp = output("0 < _forstep ? ($CVAR <= _forlimit) : (_forlimit <= $CVAR)", subs)
        end
    else
        if types.equals(node.decl._type, types.Integer) then
            cstep = output("$CVAR = l_castU2S(l_castS2U($CVAR) + 1)", subs)
        else
            cstep = output("$CVAR += 1.0", subs)
        end
        ccmp = output("$CVAR <= _forlimit", subs)
    end
    local cblock = codestat(ctx, node.block)
    popd(ctx)
    return output([[
        {
            $CSTART
            $CFINISH
            $CINC
            for($CDECL = _forstart; $CCMP; $CSTEP) {
                $CBLOCK
            }
        }
    ]], {
        CSTART = cstart,
        CFINISH = cfinish,
        CINC = cinc,
        CDECL = cdecl,
        CCMP = ccmp,
        CSTEP = cstep,
        CBLOCK = cblock
    })
end

local function codeassignment(ctx, node)
    -- has to generate different code if lvar is just a variable
    -- or an array indexing.
    local vtag = node.var._tag
    if vtag == "Var_Name" then
        if node.var._decl._tag == "TopLevel_Var" and not node.var._decl.islocal then
            local cstats, cexp = codeexp(ctx, node.exp)
            return output([[
                $CSTATS
                $SETSLOT
            ]], {
                CSTATS = cstats,
                SETSLOT = setslot(node.var._type, node.var._decl._slot, cexp)
            })
        else
            local cstats, cexp = codeexp(ctx, node.exp, false, node.var._decl)
            local cset = ""
            if types.is_gc(node.var._type) then
                cset = output([[
                    /* update slot */
                    $SETSLOT
                ]], {
                    SETSLOT = setslot(node.var._type, node.var._decl._slot, node.var._decl._cvar)
                })
            end
            return output([[
                {
                    $CSTATS
                    $CVAR = $CEXP;
                    $CSET
                }
            ]], {
                CSTATS = cstats,
                CVAR = node.var._decl._cvar,
                CEXP = cexp,
                CSET = cset,
            })
        end
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
            cset = output([[
                TValue _vv;
                $SETSLOT
                setobj2t(L, _slot, &_vv);
                luaC_barrierback(L, _t, &_vv);
            ]], {
                SETSLOT = setslot(etype, "&_vv", cexp)
            })
        else
            cset = setslot(etype, "_slot", cexp)
        end
        return output([[
            {
                $CASTATS
                $CISTATS
                $CSTATS
                Table *_t = $CAEXP;
                lua_Integer _k = $CIEXP;
                unsigned int _actual_i = l_castS2U(_k) - 1;
                unsigned int _asize = _t->sizearray;
                TValue *_slot;
                if (_actual_i < _asize) {
                    _slot = &_t->array[_actual_i];
                } else if (_actual_i < 2*_asize) {
                    unsigned int _hsize = sizenode(_t);
                    luaH_resize(L, _t, 2*_asize, _hsize);
                    _slot = &_t->array[_actual_i];
                } else {
                    _slot = (TValue *)luaH_getint(_t, _k);
                    TValue _vk; setivalue(&_vk, _k);
                    if (_slot == luaO_nilobject)    /* no previous entry? */
                            _slot = luaH_newkey(L, _t, &_vk);    /* create one */
                }
                $CSET
            }
        ]], {
            CASTATS = castats,
            CISTATS = cistats,
            CSTATS = cstats,
            CAEXP = caexp,
            CIEXP = ciexp,
            CSET = cset
        })
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
    local cstats = table.concat(castats, "\n")
    local ccall = output("$NODENAME_titan($CAEXPS)", {
        NODENAME = node.exp.var.name,
        CAEXPS = table.concat(caexps, ", "),
    })
    if types.is_gc(node._type) then
        local ctmp, tmpname, tmpslot = newtmp(ctx, node._type, true)
        return output([[
            $CSTATS
            $CTMP
            $TMPNAME = $CCALL;
            $SETSLOT;
        ]], {
            CSTATS = cstats,
            CTMP = ctmp,
            TMPNAME = tmpname,
            CCALL = ccall,
            SETSLOT = setslot(node._type, tmpslot, tmpname),
        }), tmpname
    else
        return cstats, ccall
    end
end

local function codereturn(ctx, node)
    local cstats, cexp = codeexp(ctx, node.exp)
    local tmpl
    if types.equals(node._type, types.String) then
        tmpl = [[
            {
                $CSTATS
                TString *ret = $CEXP;
                setsvalue(L, _retslot, ret);
                L->top = _retslot + 1;
                return ret;
            }
        ]]
    elseif types.has_tag(node._type, "Array") then
        tmpl = [[
            {
                $CSTATS
                Table *ret = $CEXP;
                sethvalue(L, _retslot, ret);
                L->top = _retslot + 1;
                return ret;
            }
        ]]
    elseif ctx.nslots > 0 then
        tmpl = [[
            $CSTATS
            L->top = _base;
            return $CEXP;
        ]]
    else
        tmpl = [[
            $CSTATS
            return $CEXP;
        ]]
    end
    return output(tmpl, {
        CSTATS = cstats,
        CEXP = cexp,
    })
end

function codestat(ctx, node)
    local tag = node._tag
    if tag == "Stat_Decl" then
        local cstats, cexp = codeexp(ctx, node.exp)
        if node.decl._used then
            local typ = node.decl._type
            node.decl._cvar = "_local_" .. node.decl.name
            local cdecl = ctype(typ) .. " " .. node.decl._cvar .. ";"
            local cslot = ""
            local cset = ""
            if types.is_gc(typ) then
                node.decl._slot = "_localslot_" .. node.decl.name
                cslot = newslot(ctx, node.decl._slot);
                cset = output([[
                    /* update slot */
                    $SETSLOT
                ]], {
                    SETSLOT = setslot(typ, node.decl._slot, node.decl._cvar),
                })
            end
            return output([[
                $CDECL
                $CSLOT
                {
                    $CSTATS
                    $CVAR = $CEXP;
                    $CSET
                }
            ]], {
                CDECL = cdecl,
                CSLOT = cslot,
                CSTATS = cstats,
                CVAR = node.decl._cvar,
                CEXP = cexp,
                CSET = cset
            })
        else
            return output([[
                $CSTATS
                ((void)$CEXP);
            ]], {
                CSTATS = cstats,
                CEXP = cexp
            })
        end
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
        error("invalid node tag " .. tag)
    end
end

-- All the code generation functions for EXPRESSIONS return
-- preliminary C code necessary for computing the expression
-- as a string of C statements, plus the code for the expression
-- as a string with a C expression. For trivial expressions
-- the preliminary code is always the empty string

local function codevar(ctx, node)
    if node._decl._tag == "TopLevel_Var" and not node._decl.islocal then
        return "", getslot(node._type, nil, node._decl._slot)
    else
        return "", node._decl._cvar
    end
end

local function codevalue(ctx, node, target)
    local tag = node._tag
    if tag == "Exp_Nil" then
        return "", "0"
    elseif tag == "Exp_Bool" then
        return "", node.value and "1" or "0"
    elseif tag == "Exp_Integer" then
        return "", string.format("%i", node.value)
    elseif tag == "Exp_Float" then
        return "", string.format("%f", node.value)
    elseif tag == "Exp_String" then
        local cstr = output("luaS_new(L, $QUOTED)", { QUOTED = quotestr(node.value) })
        if target then
            return "", cstr
        else
            local ctmp, tmpname, tmpslot = newtmp(ctx, types.String, true)
            return output([[
                $CTMP
                $TMPNAME = $CSTR;
                setsvalue(L, $TMPSLOT, $TMPNAME);
            ]], {
                CTMP = ctmp,
                TMPNAME = tmpname,
                CSTR = cstr,
                TMPSLOT = tmpslot,
            }), tmpname
        end
    else
        error("invalid tag for a literal value: " .. tag)
    end
end

local function codetable(ctx, node, target)
    local stats = {}
    local cinit, ctmp, tmpname, tmpslot
    if target then
        ctmp, tmpname, tmpslot = "", target._cvar, target._slot
        cinit = string.format([[
            %s = luaH_new(L);
            sethvalue(L, %s, %s);
        ]], target._cvar, target._slot)
    else
        ctmp, tmpname, tmpslot = newtmp(ctx, node._type, true)
        cinit = string.format([[
            %s
            %s = luaH_new(L);
            sethvalue(L, %s, %s);
        ]], ctmp, tmpname, tmpslot, tmpname)
    end
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

local function codeunaryop(ctx, node, iscondition)
    local op = node.op
    if op == "not" then
        local estats, ecode = codeexp(ctx, node.exp, iscondition)
        return estats, "!(" .. ecode .. ")"
    elseif op == "#" then
        local estats, ecode = codeexp(ctx, node.exp)
        if types.has_tag(node.exp._type, "Array") then
            return estats, "luaH_getn(" .. ecode .. ")"
        else
            return estats, "tsslen(" .. ecode .. ")"
        end
    else
        local estats, ecode = codeexp(ctx, node.exp)
        return estats, "(" .. op .. ecode .. ")"
    end
end

local function codebinaryop(ctx, node, iscondition)
    local op = node.op
    if op == "//" then op = "/" end
    if op == "~=" then op = "!=" end
    if op == "and" then
        local lstats, lcode = codeexp(ctx, node.lhs, iscondition)
        local rstats, rcode = codeexp(ctx, node.rhs, iscondition)
        if lstats == "" and rstats == "" then
            return "(" .. lcode .. " && " .. rcode .. ")"
        else
            local ctmp, tmpname, tmpslot = newtmp(ctx, node._type, types.is_gc(node._type))
            local tmpset = types.is_gc(node._type) and setslot(node._type, tmpslot, tmpname) or ""
            return string.format([[
                %s
                %s
                %s = %s;
                if(%s) {
                  %s
                  %s = %s;
                }
                %s;
            ]], lstats, ctmp, tmpname, lcode, tmpname, rstats, tmpname, rcode, tmpset), tmpname
        end
    elseif op == "or" then
        local lstats, lcode = codeexp(ctx, node.lhs, true)
        local rstats, rcode = codeexp(ctx, node.rhs, iscondition)
        if lstats == "" and rstats == "" then
            return "(" .. lcode .. " || " .. rcode .. ")"
        else
            local ctmp, tmpname, tmpslot = newtmp(ctx, node._type, types.is_gc(node._type))
            local tmpset = types.is_gc(node._type) and setslot(node._type, tmpslot, tmpname) or ""
            return string.format([[
                %s
                %s
                %s = %s;
                if(!%s) {
                  %s
                  %s = %s;
                }
                %s;
            ]], lstats, ctmp, tmpname, lcode, tmpname, rstats, tmpname, rcode, tmpset), tmpname
        end
    elseif op == "^" then
        local lstats, lcode = codeexp(ctx, node.lhs)
        local rstats, rcode = codeexp(ctx, node.rhs)
        return lstats .. rstats, "pow(" .. lcode .. ", " .. rcode .. ")"
    else
        local lstats, lcode = codeexp(ctx, node.lhs)
        local rstats, rcode = codeexp(ctx, node.rhs)
        return lstats .. rstats, "(" .. lcode .. op .. rcode .. ")"
    end
end

local function codeindex(ctx, node, iscondition)
    local castats, caexp = codeexp(ctx, node.exp1)
    local cistats, ciexp = codeexp(ctx, node.exp2)
    local typ = node._type
    local ctmp, tmpname, tmpslot = newtmp(ctx, typ, types.is_gc(typ))
    local cset = ""
    local ccheck = checkandget(typ, tmpname, "_s", node._lin)
    if types.is_gc(typ) then
        cset = setslot(typ, tmpslot, tmpname)
    end
    local cfinish
    if iscondition then
        cfinish = string.format([[
          if(ttisnil(_s)) {
            %s = 0;
          } else {
            %s
            %s
          }
        ]], tmpname, ccheck, cset)
    else
        cfinish = string.format([[
            %s
            %s
        ]], ccheck, cset)
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
    }]], ctmp, castats, cistats, caexp, ciexp, cfinish)
    return stats, tmpname
end

-- Generate code for expression 'node'
-- 'iscondition' is 'true' if expression is used not for value but for
--    controlling conditinal execution
-- 'target' is not nil if expression is rvalue for a 'Var_Name' lvalue,
--    in this case it will be the '_decl' of the lvalue
function codeexp(ctx, node, iscondition, target)
    local tag = node._tag
    if tag == "Var_Name" then
        return codevar(ctx, node)
    elseif tag == "Var_Index" then
        return codeindex(ctx, node, iscondition)
    elseif tag == "Exp_Nil" or
                tag == "Exp_Bool" or
                tag == "Exp_Integer" or
                tag == "Exp_Float" or
                tag == "Exp_String" then
            return codevalue(ctx, node, target)
    elseif tag == "Exp_Table" then
            return codetable(ctx, node, target)
    elseif tag == "Exp_Var" then
        return codeexp(ctx, node.var, iscondition)
    elseif tag == "Exp_Unop" then
            return codeunaryop(ctx, node, iscondition)
    elseif tag == "Exp_Binop" then
            return codebinaryop(ctx, node, iscondition)
    elseif tag == "Exp_Call" then
        return codecall(ctx, node, target)
    elseif tag == "Exp_ToFloat" then
        local cstat, cexp = codeexp(ctx, node.exp)
        return cstat, "((lua_Number)" .. cexp .. ")"
    elseif tag == "Exp_ToBool" then
        local cstat, cexp = codeexp(ctx, node.exp, true)
        return cstat, "((" .. cexp .. ") ? 1 : 0)"
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
            %s = %s;
            %s = l_floor(%s);
            if (%s != %s) %s = 0; else lua_numbertointeger(%s, &%s);
        ]], cstat, ctmp1, ctmp2, ctmp3, tmpname1, cexp, tmpname2, tmpname1, tmpname1,
            tmpname2, tmpname3, tmpname2, tmpname3)
        return cfloor, tmpname3
    elseif tag == "Exp_ToStr" then
        local cvt
        local cstats, cexp = codeexp(ctx, node.exp)
        if types.equals(node.exp._type, types.Integer) then
            cvt = string.format("_integer2str(L, %s)", cexp)
        elseif types.equals(node.exp._type, types.Float) then
            cvt = string.format("_float2str(L, %s)", cexp)
        else
            error("invalid node type for coercion to string " .. types.tostring(node.exp._type))
        end
        if target then
            return cstats, cvt
        else
            local ctmp, tmpname, tmpslot = newtmp(ctx, types.String, true)
            return string.format([[
                %s
                %s = %s;
                setsvalue(L, %s, %s);
            ]], ctmp, tmpname, cvt, tmpslot, tmpname), tmpname
        end
    elseif tag == "Exp_Concat" then
        local strs, copies = {}, {}
        local ctmp, tmpname, tmpslot = newtmp(ctx, types.String, true)
        for i, exp in ipairs(node.exps) do
            local cstat, cexp = codeexp(ctx, exp)
            table.insert(strs, string.format([[
                %s
                TString *_str%d = %s;
                size_t _len%d = tsslen(_str%d);
                _len += _len%d;
            ]], cstat, i, cexp, i, i, i))
            table.insert(copies, string.format([[
                memcpy(_buff + _tl, getstr(_str%d), _len%d * sizeof(char));
                _tl += _len%d;
            ]], i, i, i))
        end
        return string.format([[
          %s
          {
          size_t _len = 0;
          size_t _tl = 0;
          %s
          if(_len <= LUAI_MAXSHORTLEN) {
              char _buff[LUAI_MAXSHORTLEN];
              %s
              %s = luaS_newlstr(L, _buff, _len);
          } else {
              %s = luaS_createlngstrobj(L, _len);
              char *_buff = getstr(%s);
              %s
          }
          }
          setsvalue(L, %s, %s);
        ]], ctmp, table.concat(strs, "\n"),
            table.concat(copies, "\n"), tmpname, tmpname, tmpname,
            table.concat(copies, "\n"), tmpslot, tmpname), tmpname
    else
        error("invalid node tag " .. tag)
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
        table.insert(stats, ctype(param._type) .. " " .. param._cvar .. " = 0;")
        table.insert(stats, checkandget(param._type, param._cvar,
            "(func+ " .. i .. ")", node._lin))
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

local function codevardec(tlctx, ctx, node)
    local cstats, cexp = codeexp(ctx, node.value)
    if node.islocal then
        node._cvar = "_global_" .. node.decl.name
        node._cdecl = "static " .. ctype(node._type) .. " " .. node._cvar .. ";"
        node._init = string.format([[
            %s
            %s = %s;
        ]], cstats, node._cvar, cexp)
        if types.is_gc(node._type) then
            node._slot = "_globalslot_" .. node.decl.name
            node._cdecl = "static TValue *" .. node._slot .. ";\n" ..
                node._cdecl
            node._init = string.format([[
                %s
                %s;
                ]], node._init, setslot(node._type, node._slot, node._cvar))
        end
    else
        node._slot = node.decl.name .. "_titanvar"
        node._cdecl = "TValue *" .. node._slot .. ";"
        node._init = string.format([[
            %s
            %s;
        ]], cstats, setslot(node._type, node._slot, cexp))
    end
end

local preamble = [[
#include <string.h>
#include "luaconf.h"

#include "lauxlib.h"
#include "lualib.h"

#include "lapi.h"
#include "lgc.h"
#include "ltable.h"
#include "lstring.h"
#include "lvm.h"

#include "lobject.h"

#include <math.h>

#define MAXNUMBER2STR 50

static char _cvtbuff[MAXNUMBER2STR];

inline static TString* _integer2str (lua_State *L, lua_Integer i) {
    size_t len;
    len = lua_integer2str(_cvtbuff, sizeof(_cvtbuff), i);
    return luaS_newlstr(L, _cvtbuff, len);
}

inline static TString* _float2str (lua_State *L, lua_Number f) {
    size_t len;
    len = lua_number2str(_cvtbuff, sizeof(_cvtbuff), f);
    return luaS_newlstr(L, _cvtbuff, len);
}

]]

local postamble = [[
int luaopen_%s(lua_State *L) {
    %s_init(L);
    lua_newtable(L);
    %s
    luaL_setmetatable(L, "titan module %s");
    return 1;
}
]]

local init = [[
void %s_init(lua_State *L) {
    if(!_initialized) {
        _initialized = 1;
        %s
    }
}
]]

function coder.generate(modname, ast)
    local tlcontext = {
        module = modname,
    }

    local code = { preamble }

    -- has this module already been initialized?
    table.insert(code, "static int _initialized = 0;")

    local funcs = {}
    local initvars = {}
    local varslots = {}
    local gvars = {}

    local initctx = newcontext()

    for _, node in pairs(ast) do
        if not node._ignore then
            local tag = node._tag
            if tag == "TopLevel_Func" then
                -- ignore functions in the first pass
            elseif tag == "TopLevel_Var" then
                codevardec(tlcontext, initctx, node)
                table.insert(code, node._cdecl)
                table.insert(initvars, node._init)
                table.insert(varslots, node._slot)
                if not node.islocal then
                    table.insert(gvars, node)
                end
            else
                error("invalid node tag " .. tag)
            end
        end
    end

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
                -- ignore vars in second pass
            else
                error("invalid node tag " .. tag)
            end
        end
    end

    if initctx.nslots + #varslots > 0 then
        local switch_get, switch_set = {}, {}

        for i, var in ipairs(gvars) do
            table.insert(switch_get, string.format([[
                case %d: setobj2t(L, L->top-1, %s); break;
            ]], i, var._slot))
            table.insert(switch_set, string.format([[
                case %d: {
                    lua_pushvalue(L, 3);
                    %s;
                    break;
                }
            ]], i, checkandset(var._type, var._slot, "L->top-1", var._lin)))
        end

        table.insert(code, string.format([[
            static int __index(lua_State *L) {
                lua_pushvalue(L, 2);
                lua_rawget(L, lua_upvalueindex(1));
                if(lua_isnil(L, -1)) {
                    return luaL_error(L,
                        "global variable '%%s' does not exist in Titan module '%%s'",
                        lua_tostring(L, 2), "%s");
                }
                switch(lua_tointeger(L, -1)) {
                    %s
                }
                return 1;
            }

            static int __newindex(lua_State *L) {
                lua_pushvalue(L, 2);
                lua_rawget(L, lua_upvalueindex(1));
                if(lua_isnil(L, -1)) {
                    return luaL_error(L,
                        "global variable '%%s' does not exist in Titan module '%%s'",
                        lua_tostring(L, 2), "%s");
                }
                switch(lua_tointeger(L, -1)) {
                    %s
                }
                return 1;
            }
         ]], modname, table.concat(switch_get, "\n"), modname, table.concat(switch_set, "\n")))

        local nslots = initctx.nslots + #varslots + 1

        table.insert(initvars, 1, string.format([[
        luaL_newmetatable(L, "titan module %s"); /* push metatable */
        int _meta = lua_gettop(L);
        TValue *_base = L->top;
        /* protect it */
        lua_pushliteral(L, "titan module %s");
        lua_setfield(L, -2, "__metatable");
        /* reserve needed stack space */
        if (L->stack_last - L->top > %d) {
            if (L->ci->top < L->top + %d) L->ci->top = L->top + %d;
        } else {
            lua_checkstack(L, %d);
        }
        L->top += %d;
        for(TValue *_s = L->top - 1; _base <= _s; _s--)
            setnilvalue(_s);
        Table *_map = luaH_new(L);
        sethvalue(L, L->top-%d, _map);
        lua_pushcclosure(L, __index, %d);
        TValue *_upvals = clCvalue(L->top-1)->upvalue;
        lua_setfield(L, _meta, "__index");
        sethvalue(L, L->top, _map);
        L->top++;
        lua_pushcclosure(L, __newindex, 1);
        lua_setfield(L, _meta, "__newindex");
        L->top++;
        sethvalue(L, L->top-1, _map);
        ]], modname, modname, nslots, nslots, nslots, nslots, nslots, #varslots+1,
            #varslots+1))
        for i, slot in ipairs(varslots) do
            table.insert(initvars, i+1, string.format([[
              %s = &_upvals[%d];
            ]], slot, i))
        end
        for i, var in ipairs(gvars) do
            table.insert(initvars, 2, string.format([[
                lua_pushinteger(L, %d);
                lua_setfield(L, -2, "%s");
            ]], i, var.decl.name))
        end
        table.insert(initvars, string.format([[
        L->top = _base-1;
        ]], modname))
    end

    table.insert(code, string.format(init, modname, table.concat(initvars, "\n")))

    table.insert(code, string.format(postamble, modname, modname, table.concat(funcs, "\n"), modname))

    return table.concat(code, "\n\n")
end

return coder
