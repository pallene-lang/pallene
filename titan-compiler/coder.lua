local coder = {}

local codeexp, codestat

local function codefuncsig(islocal, name, params, rettype)
end

local function codeblock(node)
end

local function codewhile(node)
end

local function coderepeat(node)
end

local function codeif(node)
end

local function codefor(node)
end

local function codeassignment(node)
end

local function codecall(node)
end

local function codereturn(node)
end

function codestat(node)
	local tag = node._tag
    if tag == "Decl_Decl" then
    elseif tag == "Stat_Decl" then
		codestat(node.decl)
		codeexp(node.exp)
    elseif tag == "Stat_Block" then
		codeblock(node)
    elseif tag == "Stat_While" then
		codewhile(node)
    elseif tag == "Stat_Repeat" then
		coderepeat(node)
    elseif tag == "Stat_If" then
		codeif(node)
    elseif tag == "Stat_For" then
		codefor(node)
    elseif tag == "Stat_Assign" then
		codeassignment(node)
    elseif tag == "Stat_Call" then
		codecall(node)
    elseif tag == "Stat_Return" then
		codereturn(node)
    else
        error("code generation not implemented for node " .. tag)
    end
end

local function codevar(node)
end

local function codevalue(node)
end

local function codetable(node)
end

local function codeunaryop(node)
end

local function codebinaryop(node)
end

function codeexp(node)
    local tag = node._tag
    if tag == "Var_Name" or
	   tag == "Var_Index" then
		codevar(node)
    elseif tag == "Exp_Nil" or
    	   tag == "Exp_Bool" or
    	   tag == "Exp_Integer" or
    	   tag == "Exp_Float" or
    	   tag == "Exp_String" then
		codevalue(node)
    elseif tag == "Exp_Table" then
		codetable(node)
    elseif tag == "Exp_Var" then
		codevar(node)
    elseif tag == "Exp_Unop" then
		codeunaryop(node)
    elseif tag == "Exp_Binop" then
		codebinaryop(node)
    elseif tag == "Exp_Call" then
		codecall(node)
    else
        error("code generation not implemented for node " .. tag)
    end
end

local function codefuncdec(node)
	codefuncsig(node.islocal, node.name, node.params, node.rettype)
	codestat(node.block)
end

local function codedecl(islocal, decl, value)
end

local function codevardec(node)
	codedecl(node.islocal, node.decl, node.value)
end

function coder.generate(ast)
	for _, node in pairs(ast) do
		if not node.ignore then
			local tag = node._tag
			if tag == "TopLevel_Func" then
				codefuncdec(node)
			elseif tag == "TopLevel_Var" then
				codevardec(node)
			else
				error("code generation not implemented for node " .. tag)
			end
		end
	end
	return ""
end

return coder
