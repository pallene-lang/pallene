local types = require "titan-compiler.types"

local coder = {}

local codeexp, codestat

-- Barebones string-based template function for generating C code.
-- Replaces $VAR placeholders in the `code` template by the corresponding
-- strings in the `substs` table.
local function render(code, substs)
    return (string.gsub(code, "$([%w_]+)", function(k)
        local v = substs[k]
        if not v then
            error("Internal compiler error: missing template variable " .. k)
        end
        return v
    end))
end


--
-- Functions for C literals
--

-- Technically, we only need to escape the quote and backslash
-- But quoting some extra things helps readability...
local some_c_escape_sequences = {
    ["\\"] = "\\\\",
    ["\""] = "\\\"",
    ["\a"] = "\\a",
    ["\b"] = "\\b",
    ["\f"] = "\\f",
    ["\n"] = "\\n",
    ["\r"] = "\\r",
    ["\t"] = "\\t",
    ["\v"] = "\\v",
}

local function c_string_literal(s)
    return '"' .. (s:gsub('.', some_c_escape_sequences)) .. '"'
end

local function c_integer_literal(n)
    return string.format("%i", n)
end

local function c_float_literal(n)
    return string.format("%f", n)
end


-- Is this expression a numeric literal?
-- If yes, return that number. If not, returns nil.
--
-- This limited form of constant-folding is enough to optimize things like for
-- loops, since most of the time the loop step is a numeric literal.
-- Note to self: A constant-folding optimization pass would obsolete this
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
    return render(tmpl, { DST = dst, SRC = src })
end

local function checkandget(typ --[[:table]], cvar --[[:string]], exp --[[:string]], line --[[:number]])
    local tag
    if types.equals(typ, types.Integer) then tag = "integer"
    elseif types.equals(typ, types.Float) then
        return render([[
            if (ttisinteger($EXP)) {
                $VAR = (lua_Number)ivalue($EXP);
            } else if (ttisfloat($EXP)) {
                $VAR = fltvalue($EXP);
            } else {
                luaL_error(L, "type error at line %d, expected float but found %s", $LINE, lua_typename(L, ttnov($EXP)));
            }
        ]], {
            EXP = exp,
            VAR = cvar,
            LINE = c_integer_literal(line),
        })
    elseif types.equals(typ, types.Boolean) then tag = "boolean"
    elseif types.equals(typ, types.Nil) then tag = "nil"
    elseif types.equals(typ, types.String) then tag = "string"
    elseif types.has_tag(typ, "Array") then tag = "table"
    else
        error("invalid type " .. types.tostring(typ))
    end
    --return getslot(typ, cvar, exp) .. ";"
    return render([[
        if($PREDICATE($EXP)) {
            $GETSLOT;
        } else {
            luaL_error(L, "type error at line %d, expected %s but found %s", $LINE, $TAG, lua_typename(L, ttnov($EXP)));
        }
    ]], {
        EXP = exp,
        TAG = c_string_literal(tag),
        PREDICATE = 'ttis'..tag,
        GETSLOT = getslot(typ, cvar, exp),
        LINE = c_integer_literal(line),
    })
end

local function checkandset(typ --[[:table]], dst --[[:string]], src --[[:string]], line --[[:number]])
    local tag
    if types.equals(typ, types.Integer) then tag = "integer"
    elseif types.equals(typ, types.Float) then
        return render([[
            if (ttisinteger($SRC)) {
                setfltvalue($DST, ((lua_Number)ivalue($SRC)));
            } else if (ttisfloat($SRC)) {
                setobj2t(L, $DST, $SRC);
            } else {
                luaL_error(L, "type error at line %d, expected float but found %s", $LINE, lua_typename(L, ttnov($SRC)));
            }
        ]], {
            SRC = src,
            DST = dst,
            LINE = c_integer_literal(line),
        })
    elseif types.equals(typ, types.Boolean) then tag = "boolean"
    elseif types.equals(typ, types.Nil) then tag = "nil"
    elseif types.equals(typ, types.String) then tag = "string"
    elseif types.has_tag(typ, "Array") then tag = "table"
    else
        error("invalid type " .. types.tostring(typ))
    end
    return render([[
        if ($PREDICATE($SRC)) {
            setobj2t(L, $DST, $SRC);
        } else {
            luaL_error(L, "type error at line %d, expected %s but found %s", $LINE, $TAG, lua_typename(L, ttnov($SRC)));
        }
    ]], {
        TAG = c_string_literal(tag),
        PREDICATE = 'ttis'..tag,
        SRC = src,
        DST = dst,
        LINE = c_integer_literal(line),
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
    return render(tmpl, { DST = dst, SRC = src })
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
        allocations = 0, -- number of allocations
        depth = 0,  -- current stack depth
        dstack = {} -- stack of stack depths
    }
end

local function newslot(ctx --[[:table]], name --[[:string]])
    local sdepth = ctx.depth
    ctx.depth = ctx.depth + 1
    ctx.allocations = ctx.allocations + 1
    if ctx.depth > ctx.nslots then ctx.nslots = ctx.depth end
    return render([[
    	TValue *$NAME = _base + $SDEPTH;
    ]], {
    	NAME = name,
        SDEPTH = c_integer_literal(sdepth),
    })
end

local function newtmp(ctx --[[:table]], typ --[[:table]], isgc --[[:boolean]])
    local tmp = ctx.tmp
    ctx.tmp = ctx.tmp + 1
    local tmpname = "_tmp_" .. tmp
    if isgc then
        local slotname = "_tmp_" .. tmp .. "_slot"
        return render([[
            $NEWSLOT
            $TYPE $TMPNAME = 0;
        ]], {
            TYPE = ctype(typ),
            NEWSLOT = newslot(ctx, slotname),
            TMPNAME = tmpname,
        }), tmpname, slotname
    else
        return render([[
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
    local nallocs = ctx.allocations
    local cstats, cexp = codeexp(ctx, node.condition, true)
    local cblk = codestat(ctx, node.block)
    nallocs = ctx.allocations - nallocs
    popd(ctx)
    local tmpl
    if cstats == "" then
        tmpl = [[
            while($CEXP) {
                $CBLK
                $CHECKGC
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
                $CHECKGC
            }
        ]]
    end
    return render(tmpl, {
        CSTATS = cstats,
        CEXP = cexp,
        CBLK = cblk,
        CHECKGC = nallocs > 0 and "luaC_checkGC(L);" or ""
    })
end

local function coderepeat(ctx, node)
    pushd(ctx)
    local nallocs = ctx.allocations
    local cstats, cexp = codeexp(ctx, node.condition, true)
    local cblk = codestat(ctx, node.block)
    nallocs = ctx.allocations - nallocs
    popd(ctx)
    return render([[
        while(1) {
            $CBLK
            $CSTATS
            if($CEXP) {
                break;
            }
            $CHECKGC
        }
    ]], {
        CBLK = cblk,
        CSTATS = cstats,
        CEXP = cexp,
        CHECKGC = nallocs > 0 and "luaC_checkGC(L);" or ""
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
    return render([[
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
    local cstart = render([[
        $CSSTATS
        $CVTYP _forstart = $CSEXP;
    ]], {
        CSSTATS = csstats,
        CSEXP = csexp,
        CVTYP = cvtyp,
    })
    local cfinish = render([[
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
                local tmpl
                if types.equals(node.decl._type, types.Integer) then
                    subs.ILIT = c_integer_literal(ilit)
                    tmpl = "$CVAR = l_castU2S(l_castS2U($CVAR) + $ILIT)"
                else
                    subs.ILIT = c_float_literal(ilit)
                    tmpl = "$CVAR += $ILIT"
                end
                cstep = render(tmpl, subs)
                ccmp = render("$CVAR <= _forlimit", subs)
            else
                if types.equals(node.decl._type, types.Integer) then
                    subs.NEGILIT = c_integer_literal(-ilit)
                    cstep = render("$CVAR = l_castU2S(l_castS2U($CVAR) - $NEGILIT)", subs)
                else
                    subs.NEGILIT = c_float_literal(-ilit)
                    cstep = render("$CVAR -= $NEGILIT", subs)
                end
                ccmp = render("_forlimit <= $CVAR", subs)
            end
        else
            local cistats, ciexp = codeexp(ctx, node.inc)
            cinc = render([[
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
            cstep = render(tmpl, subs)
            ccmp = render("0 < _forstep ? ($CVAR <= _forlimit) : (_forlimit <= $CVAR)", subs)
        end
    else
        if types.equals(node.decl._type, types.Integer) then
            cstep = render("$CVAR = l_castU2S(l_castS2U($CVAR) + 1)", subs)
        else
            cstep = render("$CVAR += 1.0", subs)
        end
        ccmp = render("$CVAR <= _forlimit", subs)
    end
    local nallocs = ctx.allocations
    local cblock = codestat(ctx, node.block)
    nallocs = ctx.allocations - nallocs
    popd(ctx)
    return render([[
        {
            $CSTART
            $CFINISH
            $CINC
            for($CDECL = _forstart; $CCMP; $CSTEP) {
                $CBLOCK
                $CHECKGC
            }
        }
    ]], {
        CSTART = cstart,
        CFINISH = cfinish,
        CINC = cinc,
        CDECL = cdecl,
        CCMP = ccmp,
        CSTEP = cstep,
        CBLOCK = cblock,
        CHECKGC = nallocs > 0 and "luaC_checkGC(L);" or ""
    })
end

local function codeassignment(ctx, node)
    -- has to generate different code if lvar is just a variable
    -- or an array indexing.
    local vtag = node.var._tag
    if vtag == "Var_Name" then
        if node.var._decl._tag == "TopLevel_Var" and not node.var._decl.islocal then
            local cstats, cexp = codeexp(ctx, node.exp)
            return render([[
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
                cset = render([[
                    /* update slot */
                    $SETSLOT
                ]], {
                    SETSLOT = setslot(node.var._type, node.var._decl._slot, node.var._decl._cvar)
                })
            end
            return render([[
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
    elseif vtag == "Var_Array" then
        local arr = node.var.exp1
        local idx = node.var.exp2
        local etype = node.exp._type
        local castats, caexp = codeexp(ctx, arr)
        local cistats, ciexp = codeexp(ctx, idx)
        local cstats, cexp = codeexp(ctx, node.exp)
        local cset
        if types.is_gc(arr._type.elem) then
            -- write barrier
            cset = render([[
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
        return render([[
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
                        _slot = luaH_newkey(L, _t, &_vk);   /* create one */
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
    local ccall = render("$NAME($CAEXPS)", {
        NAME = node.exp.var.name .. '_titan',
        CAEXPS = table.concat(caexps, ", "),
    })
    if types.is_gc(node._type) then
        local ctmp, tmpname, tmpslot = newtmp(ctx, node._type, true)
        return render([[
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
                luaC_checkGC(L);
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
                luaC_checkGC(L);
                return ret;
            }
        ]]
    elseif ctx.nslots > 0 then
        tmpl = [[
            $CSTATS
            L->top = _base;
            luaC_checkGC(L);
            return $CEXP;
        ]]
    else
        tmpl = [[
            $CSTATS
            return $CEXP;
        ]]
    end
    return render(tmpl, {
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
                cset = render([[
                    /* update slot */
                    $SETSLOT
                ]], {
                    SETSLOT = setslot(typ, node.decl._slot, node.decl._cvar),
                })
            end
            return render([[
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
            return render([[
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
        return "", c_integer_literal(node.value)
    elseif tag == "Exp_Float" then
        return "", c_float_literal(node.value)
    elseif tag == "Exp_String" then
        local cstr = render("luaS_new(L, $VALUE)", {
            VALUE = c_string_literal(node.value)
        })
        if target then
            return "", cstr
        else
            local ctmp, tmpname, tmpslot = newtmp(ctx, types.String, true)
            return render([[
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
        -- TODO: double check this code, it wan't covered by tests
        -- and wan't passing anything to the second $TMPNAME placeholder
        ctmp, tmpname, tmpslot = "", target._cvar, target._slot
        cinit = render([[
            $TMPNAME = luaH_new(L);
            sethvalue(L, $TMPSLOT, $TMPNAME);
        ]], {
            TMPNAME = tmpname,
            TMPSLOT = tmpslot,
        })
    else
        ctmp, tmpname, tmpslot = newtmp(ctx, node._type, true)
        cinit = render([[
            $CTMP
            $TMPNAME = luaH_new(L);
            sethvalue(L, $TMPSLOT, $TMPNAME);
        ]], {
            CTMP = ctmp,
            TMPNAME = tmpname,
            TMPSLOT = tmpslot,
        })
    end
    table.insert(stats, cinit)
    local slots = {}
    for _, exp in ipairs(node.exps) do
        local cstats, cexp = codeexp(ctx, exp)
        local ctmpe, tmpename, tmpeslot = newtmp(ctx, node._type.elem, true)

        local code = render([[
            $CSTATS
            $CTMPE
            $TMPENAME = $CEXP;
            $SETSLOT
        ]], {
            CSTATS = cstats,
            CTMPE = ctmpe,
            TMPENAME = tmpename,
            CEXP = cexp,
            SETSLOT = setslot(node._type.elem, tmpeslot, tmpename),
        })

        table.insert(slots, tmpeslot)
        table.insert(stats, code)
    end
    if #node.exps > 0 then
        table.insert(stats, render([[
            luaH_resizearray(L, $TMPNAME, $SIZE);
        ]], {
            TMPNAME = tmpname,
            SIZE = #node.exps
        }))

    end
    local cbarrier = ""
    for i, slot in ipairs(slots) do
        table.insert(stats, render([[
            setobj2t(L, &$TMPNAME->array[$INDEX], $SLOT);
        ]], {
            TMPNAME = tmpname,
            INDEX = i-1,
            SLOT = slot
        }))
        if types.is_gc(node._type.elem) then
            table.insert(stats, render([[
                luaC_barrierback(L, $TMPNAME, $SLOT);
            ]], {
                TMPNAME = tmpname,
                SLOT = slot,
            }))
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
            local code = render([[
                $LSTATS
                $CTMP
                $TMPNAME = $LCODE;
                if($TMPNAME) {
                  $RSTATS
                  $TMPNAME = $RCODE;
                }
                $TMPSET;
            ]], {
                CTMP = ctmp,
                TMPNAME = tmpname,
                LSTATS = lstats,
                LCODE = lcode,
                RSTATS = rstats,
                RCODE = rcode,
                TMPSET = tmpset,
            })
            return code, tmpname
        end
    elseif op == "or" then
        local lstats, lcode = codeexp(ctx, node.lhs, true)
        local rstats, rcode = codeexp(ctx, node.rhs, iscondition)
        if lstats == "" and rstats == "" then
            return "(" .. lcode .. " || " .. rcode .. ")"
        else
            local ctmp, tmpname, tmpslot = newtmp(ctx, node._type, types.is_gc(node._type))
            local tmpset = types.is_gc(node._type) and setslot(node._type, tmpslot, tmpname) or ""
            local code = render([[
                $LSTATS
                $CTMP
                $TMPNAME = $LCODE;
                if(!$TMPNAME) {
                    $RSTATS;
                    $TMPNAME = $RCODE;
                }
                $TMPSET;
            ]], {
                CTMP = ctmp,
                TMPNAME = tmpname,
                LSTATS = lstats,
                LCODE = lcode,
                RSTATS = rstats,
                RCODE = rcode,
                TMPSET = tmpset,
            })
            return code, tmpname
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
        cfinish = render([[
          if(ttisnil(_s)) {
            $TMPNAME = 0;
          } else {
            $CCHECK
            $CSET
          }
        ]], {
            TMPNAME = tmpname,
            CCHECK = ccheck,
            CSET = cset,
        })
    else
        cfinish = render([[
            $CCHECK
            $CSET
        ]], {
            CCHECK = ccheck,
            CSET = cset,
        })
    end
    local stats = render([[
        $CTMP
        {
            $CASTATS
            $CISTATS
            Table *_t = $CAEXP;
            lua_Integer _k = $CIEXP;

            unsigned int _actual_i = l_castS2U(_k) - 1;

            const TValue *_s;
            if (_actual_i < _t->sizearray) {
                _s = &_t->array[_actual_i];
            } else {
                _s = luaH_getint(_t, _k);
            }

            $CFINISH
    }]], {
        CTMP = ctmp,
        CASTATS = castats,
        CISTATS = cistats,
        CAEXP = caexp,
        CIEXP = ciexp,
        CFINISH = cfinish
    })
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
    elseif tag == "Var_Array" then
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
        local cfloor = render([[
            $CSTAT
            $CTMP1
            $CTMP2
            $CTMP3
            $TMPNAME1 = $CEXP;
            $TMPNAME2 = l_floor($TMPNAME1);
            if ($TMPNAME1 != $TMPNAME2) {
                $TMPNAME3 = 0;
            } else {
                lua_numbertointeger($TMPNAME2, &$TMPNAME3);
            }
        ]], {
            CSTAT = cstat,
            CEXP = cexp,
            CTMP1 = ctmp1,
            CTMP2 = ctmp2,
            CTMP3 = ctmp3,
            TMPNAME1 = tmpname1,
            TMPNAME2 = tmpname2,
            TMPNAME3 = tmpname3,
        })
        return cfloor, tmpname3
    elseif tag == "Exp_ToStr" then
        local cvt
        local cstats, cexp = codeexp(ctx, node.exp)
        if types.equals(node.exp._type, types.Integer) then
            cvt = render("_integer2str(L, $EXP)", { EXP = cexp })
        elseif types.equals(node.exp._type, types.Float) then
            cvt = render("_float2str(L, $EXP)", { EXP = cexp })
        else
            error("invalid node type for coercion to string " .. types.tostring(node.exp._type))
        end
        if target then
            return cstats, cvt
        else
            local ctmp, tmpname, tmpslot = newtmp(ctx, types.String, true)
            local code = render([[
                $CTMP
                $TMPNAME = $CVT;
                setsvalue(L, $TMPSLOT, $TMPNAME);
            ]], {
                CTMP = ctmp,
                TMPNAME = tmpname,
                CVT = cvt,
                TMPSLOT = tmpslot,
            })
            return code, tmpname
        end
    elseif tag == "Exp_Concat" then
        local strs, copies = {}, {}
        local ctmp, tmpname, tmpslot = newtmp(ctx, types.String, true)
        for i, exp in ipairs(node.exps) do
            local cstat, cexp = codeexp(ctx, exp)
            local strvar = string.format('_str%d', i)
            local lenvar = string.format('_len%d', i)
            table.insert(strs, render([[
                $CSTAT
                TString *$STRVAR = $CEXP;
                size_t $LENVAR = tsslen($STRVAR);
                _len += $LENVAR;
            ]], {
                CSTAT = cstat,
                CEXP = cexp,
                STRVAR = strvar,
                LENVAR = lenvar,
            }))
            table.insert(copies, render([[
                memcpy(_buff + _tl, getstr($STRVAR), $LENVAR * sizeof(char));
                _tl += $LENVAR;
            ]], {
                STRVAR = strvar,
                LENVAR = lenvar,
            }))
        end
        local code = render([[
          $CTMP
          {
              size_t _len = 0;
              size_t _tl = 0;
              $STRS
              if(_len <= LUAI_MAXSHORTLEN) {
                  char _buff[LUAI_MAXSHORTLEN];
                  $COPIES
                  $TMPNAME = luaS_newlstr(L, _buff, _len);
              } else {
                  $TMPNAME = luaS_createlngstrobj(L, _len);
                  char *_buff = getstr($TMPNAME);
                  $COPIES
              }
          }
          setsvalue(L, $TMPSLOT, $TMPNAME);
        ]], {
            CTMP = ctmp,
            STRS = table.concat(strs, "\n"),
            COPIES = table.concat(copies, "\n"),
            TMPNAME = tmpname,
            TMPSLOT = tmpslot,
        })
        return code, tmpname
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
        table.insert(stats, 1, render([[
        /* function preamble: reserve needed stack space */
        if (L->stack_last - L->top > $NSLOTS) {
            if (L->ci->top < L->top + $NSLOTS) L->ci->top = L->top + $NSLOTS;
        } else {
            lua_checkstack(L, $NSLOTS);
        }
        TValue *_base = L->top;
        L->top += $NSLOTS;
        for(TValue *_s = L->top - 1; _base <= _s; _s--)
            setnilvalue(_s);
        ]], {
            NSLOTS = c_integer_literal(nslots),
        }))
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
            luaC_checkGC(L);
            return 0;]])
        else
            table.insert(stats, "        return 0;")
        end
    end
    node._body = render([[
    static $RETTYPE $NAME($PARAMS) {
        $BODY
    }]], {
        RETTYPE = ctype(node._type.ret),
        NAME = node.name .. '_titan',
        PARAMS = table.concat(cparams, ", "),
        BODY = table.concat(stats, "\n")
    })
    -- generate Lua entry point
    local stats = {}
    local pnames = { "L" }
    for i, param in ipairs(node.params) do
        table.insert(pnames, param._cvar)
        table.insert(stats, ctype(param._type) .. " " .. param._cvar .. " = 0;")
        table.insert(stats, checkandget(param._type, param._cvar,
            "(func+ " .. i .. ")", node._lin))
    end
    table.insert(stats, render([[
        $TYPE res = $NAME($PARAMS);
        $SETSLOT
        api_incr_top(L);
        return 1;
    ]], {
        TYPE = ctype(node._type.ret),
        NAME = node.name .. '_titan',
        PARAMS = table.concat(pnames, ", "),
        SETSLOT = setslot(node._type.ret, "L->top", "res"),
    }))
    node._luabody = render([[
    static int $LUANAME(lua_State *L) {
        TValue *func = L->ci->func;
        if((L->top - func - 1) != $EXPECTED) {
            luaL_error(L, "calling Titan function %s with %d arguments, but expected %d", $NAME, L->top - func - 1, $EXPECTED);
        }
        $BODY
    }]], {
        LUANAME = node.name .. '_lua',
        EXPECTED = c_integer_literal(#node.params),
        NAME = c_string_literal(node.name),
        BODY = table.concat(stats, "\n"),
    })
end

local function codevardec(tlctx, ctx, node)
    local cstats, cexp = codeexp(ctx, node.value)
    if node.islocal then
        node._cvar = "_global_" .. node.decl.name
        node._cdecl = "static " .. ctype(node._type) .. " " .. node._cvar .. ";"
        node._init = render([[
            $CSTATS
            $CVAR = $CEXP;
        ]], {
            CSTATS = cstats,
            CVAR = node._cvar,
            CEXP = cexp,
        })
        if types.is_gc(node._type) then
            node._slot = "_globalslot_" .. node.decl.name
            node._cdecl = "static TValue *" .. node._slot .. ";\n" ..
                node._cdecl
            node._init = render([[
                $INIT
                $SET;
            ]], {
                INIT = node._init,
                SET = setslot(node._type, node._slot, node._cvar)
            })
        end
    else
        node._slot = node.decl.name .. "_titanvar"
        node._cdecl = "TValue *" .. node._slot .. ";"
        node._init = render([[
            $CSTATS
            $SET;
        ]], {
            CSTATS = cstats,
            SET = setslot(node._type, node._slot, cexp)
        })
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
int $LUAOPEN_NAME(lua_State *L) {
    $INITNAME(L);
    lua_newtable(L);
    $FUNCS
    luaL_setmetatable(L, $MODNAMESTR);
    return 1;
}
]]

local init = [[
void $INITNAME(lua_State *L) {
    if(!_initialized) {
        _initialized = 1;
        $INITVARS
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
                    table.insert(funcs, render([[
                        lua_pushcfunction(L, $LUANAME);
                        lua_setfield(L, -2, $NAMESTR);
                    ]], {
                        LUANAME = node.name .. '_lua',
                        NAMESTR = c_string_literal(node.name),
                    }))
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
            table.insert(switch_get, render([[
                case $I: setobj2t(L, L->top-1, $SLOT); break;
            ]], {
                I = c_integer_literal(i),
                SLOT = var._slot
            }))
            table.insert(switch_set, render([[
                case $I: {
                    lua_pushvalue(L, 3);
                    $SETSLOT;
                    break;
                }
            ]], {
                I = c_integer_literal(i),
                SETSLOT = checkandset(var._type, var._slot, "L->top-1", var._lin)
            }))
        end

        table.insert(code, render([[
            static int __index(lua_State *L) {
                lua_pushvalue(L, 2);
                lua_rawget(L, lua_upvalueindex(1));
                if(lua_isnil(L, -1)) {
                    return luaL_error(L,
                        "global variable '%s' does not exist in Titan module '%s'",
                        lua_tostring(L, 2), $MODSTR);
                }
                switch(lua_tointeger(L, -1)) {
                    $SWITCH_GET
                }
                return 1;
            }

            static int __newindex(lua_State *L) {
                lua_pushvalue(L, 2);
                lua_rawget(L, lua_upvalueindex(1));
                if(lua_isnil(L, -1)) {
                    return luaL_error(L,
                        "global variable '%s' does not exist in Titan module '%s'",
                        lua_tostring(L, 2), $MODSTR);
                }
                switch(lua_tointeger(L, -1)) {
                    $SWITCH_SET
                }
                return 1;
            }
         ]], {
             MODSTR = c_string_literal(modname),
             SWITCH_GET = table.concat(switch_get, "\n"),
             SWITCH_SET = table.concat(switch_set, "\n"),
         }))

        local nslots = initctx.nslots + #varslots + 1

        table.insert(initvars, 1, render([[
        luaL_newmetatable(L, $MODNAMESTR); /* push metatable */
        int _meta = lua_gettop(L);
        TValue *_base = L->top;
        /* protect it */
        lua_pushliteral(L, $MODNAMESTR);
        lua_setfield(L, -2, "__metatable");
        /* reserve needed stack space */
        if (L->stack_last - L->top > $NSLOTS) {
            if (L->ci->top < L->top + $NSLOTS) L->ci->top = L->top + $NSLOTS;
        } else {
            lua_checkstack(L, $NSLOTS);
        }
        L->top += $NSLOTS;
        for(TValue *_s = L->top - 1; _base <= _s; _s--)
            setnilvalue(_s);
        Table *_map = luaH_new(L);
        sethvalue(L, L->top-$VARSLOTS, _map);
        lua_pushcclosure(L, __index, $VARSLOTS);
        TValue *_upvals = clCvalue(L->top-1)->upvalue;
        lua_setfield(L, _meta, "__index");
        sethvalue(L, L->top, _map);
        L->top++;
        lua_pushcclosure(L, __newindex, 1);
        lua_setfield(L, _meta, "__newindex");
        L->top++;
        sethvalue(L, L->top-1, _map);
        ]], {
            MODNAMESTR = c_string_literal("titan module "..modname),
            NSLOTS = c_integer_literal(nslots),
            VARSLOTS = c_integer_literal(#varslots+1),
        }))
        for i, slot in ipairs(varslots) do
            table.insert(initvars, i+1, render([[
                $SLOT = &_upvals[$I];
            ]], {
                SLOT = slot,
                I = c_integer_literal(i),
            }))
        end
        for i, var in ipairs(gvars) do
            table.insert(initvars, 2, render([[
                lua_pushinteger(L, $I);
                lua_setfield(L, -2, $NAME);
            ]], {
                I = c_integer_literal(i),
                NAME = c_string_literal(var.decl.name)
            }))
        end
        table.insert(initvars, [[
        L->top = _base-1;
        ]])
    end

    table.insert(code, render(init, {
        INITNAME = modname .. '_init',
        INITVARS = table.concat(initvars, "\n")
    }))

    table.insert(code, render(postamble, {
        LUAOPEN_NAME = 'luaopen_' .. modname,
        INITNAME = modname .. '_init',
        FUNCS = table.concat(funcs, "\n"),
        MODNAMESTR = c_string_literal("titan module "..modname),
    }))

    return table.concat(code, "\n\n")
end

return coder
