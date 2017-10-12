local coder = {}

local codeexp, codestat

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
		tmp = 1,   -- next temporary index (for generating temporary names)
		nslots = 0 -- number of slots needed by function
	}
end

-- All the code generation functions for STATEMENTS take
-- the function context and the AST node and return the 
-- generated C code for the statement, as a string

local function codeblock(ctx, node)
  local stats = {}
	for _, stat in ipairs(node.stats) do
		table.insert(stats, codestat(ctx, stat))
	end
	return "{\n" .. table.concat(stats, "\n") .. "\n}"
end

local function codewhile(ctx, node)
end

local function coderepeat(ctx, node)
end

local function codeif(ctx, node)
end

local function codefor(ctx, node)
end

local function codeassignment(ctx, node)
  -- has to generate different code if lvar is just a variable
	-- or an array indexing.
	-- watch out for write barrier
end

local function codecall(ctx, node)
end

local function codereturn(ctx, node)
  local cstats, cexp = codeexp(ctx, node.exp)
	return "return " .. cexp .. ";" 
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
	/* check if stack needs to grow */
  if (L->stack_last - L->top > %d) { 
	  if (L->ci->top < L->top + n) L->ci->top = L->top + n; 
  } else lua_checkstack(L, %d);"]], nlocals))
	if types.is_gc(node._type.ret) then
		table.insert(stats, "L->top->tt_ = LUA_TNIL; L->top++;")
	end
	table.insert(stats, body)
	if nslots > 1 then table.insert(stats, "L->top -= " .. nslots - 1) end
	node._body = string.format([[
	static %s %s_titan(lua_State *L, %s) {
	  %s
	}]], ctype(node._type.ret), node.name, table.concat(cparams, ", "), table.concat(stats, "\n"))
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

	for _, node in pairs(ast) do
		if not node._ignore then
			local tag = node._tag
			if tag == "TopLevel_Func" then
				local body = codefuncdec(tlcontext, node)
			elseif tag == "TopLevel_Var" then
				codevardec(tlcontext, node)
			else
				error("code generation not implemented for node " .. tag)
			end
		end
	end
	return ""
end

return coder
