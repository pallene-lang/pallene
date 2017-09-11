local parser = {}

local pg = require 'parser-gen'
local peg = require 'peg-parser'
local ast = require 'titan-compiler.ast'

-- Functions used by the PEG grammar
local defs = {}

defs.tonumber = tonumber

function defs.opt(x)
    if x == '' then
        return false
    else
        return x
    end
end

function defs.boolopt(x)
    return x ~= ''
end

function defs.ifstat(exp, block, thens, elseopt)
    table.insert(ast.Then.Then(exp, block), thens, 1) 
    return ast.State.If(thens, elseopt)
end

function defs.defstat(decl, exp)
    local decl = ast.Stat.Decl(decl)
    local assign = ast.Stat.Assign(ast.Var.Name(decl.name), exp)
    return decl, assign
end

function defs.totrue()
    return true
end

function defs.tofalse()
    return false
end

function defs.prefixname(name)
    return ast.Exp.Var(ast.Var.Name(name))
end

function defs.varindex(prefix, suffixes, index)
    local exp = prefix
    for _, suffix in ipairs(suffixes) do
        if suffix._typename == 'Call' then
            exp = ast.Exp.Call(exp, suffix)
        elseif suffix._typename == 'Exp' then
            local var = ast.Var.Index(exp, suffix)
            exp = ast.Exp.Var(var)
        else
            error('impossible')
        end
    end
    return ast.Var.Index(exp, index)
end

-- Add ast constructors to defs
for type, conss in pairs(ast) do
    for consname, cons in pairs(conss) do
        defs[type .. '_' .. consname] = cons
    end
end

local grammar = pg.compile([[

    program         <- {| (toplevelfunc / toplevelvar)* |} !.

    toplevelfunc    <- (localopt 'function' NAME
                        '(' parlist ')' ':' type
                        block 'end')                    -> TopLevel_Func

    toplevelvar     <- (localopt decl '=' exp)          -> TopLevel_Var

    localopt        <- ('local'?)                       -> boolopt

    parlist         <- {| (par (',' par)*)? |}          -- produces {Decl}

    par             <- (NAME ':' type)                  -> Decl_Decl

    decl            <- (NAME (':' type)? -> opt)        -> Decl_Decl

    type            <- (TYPENAME)                       -> Type_Basic 
                     / ('{' type '}')                   -> Type_Array

    block           <- {| statement* returnstat? |}     -- produces {Stat}

    statement       <- (';')                            -- ignore ';'
                     / ('do' block 'end')               -> Stat_Block
                     / ('while' exp 'do' block 'end')   -> Stat_While
                     / ('repeat' block 'util' exp)      -> Stat_Repeat
                     / ('if' exp 'then' block
                        elseifstats elseopt 'end')      -> ifstat
                     / ('for' NAME '=' exp ',' exp
                        (',' exp)? -> opt
                        'do' block 'end')               -> Stat_For
                     / ('local' decl '=' exp)           -> defstat
                     / (var '=' exp)                    -> Stat_Assign
                     / (functioncall)                   -> Stat_Call

    elseifstats     <- {| elseifstat* |}                -- produces {Then}

    elseifstat      <- ('elseif' exp 'then' block)      -> Then_Then

    elseopt         <- ('else' block)?                  -> opt

    returnstat      <- ('return' (exp? -> opt) ';'?)    -> Stat_Return

    value           <- ('nil')                          -> Exp_Nil
                     / (BOOL)                           -> Exp_Bool
                     / (FLOAT)                          -> Exp_Float
                     / (INTEGER)                        -> Exp_Integer
                     / (STRING)                         -> Exp_String
                     / (tablecons)                      -- produces Exp
                     / (functioncall)                   -- produces Exp
                     / (var)                            -> Exp_Var
                     / ('(' exp ')')                    -- produces Exp

    exp             <- (unop exp)                       -> Exp_Unop
                     / (value binop exp)                -> Exp_Binop
                     / (value)                          -- produces Exp

    index           <- ('[' exp ']')                    -- produces Exp

    call            <- (args)                           -> Args_Func
                     / (':' NAME args)                  -> Args_Method

    varprefix       <- ('(' exp ')')                    -- produces Exp
                     / (NAME)                           -> prefixname

    varsuffix       <- (call)                           -- produces Call
                     / (index)                          -- produces Exp

    var             <- (varprefix
                        {| (varsuffix &varsuffix)* |}
                        index)                          -> varindex
                     / NAME                             -> Var_Name

    functioncall    <- (NAME call)                      -> Exp_Call

    args            <- ('(' explist ')')                -- produces {Exp}
                     / {| tablecons |}                  -- produces {Exp}
                     / {| STRING -> Exp_String |}       -- produces {Exp}

    explist         <- {| (exp (',' exp)*)? |}          -- produces {Exp}

    tablecons       <- ('{' {| fieldlist? |} '}')       -> Exp_Table

    fieldlist       <- (exp (fieldsep exp)* fieldsep?)  -- produces Exp...

    fieldsep        <- ';' / ','

    binop           <- {'+' / '-' / '*' / '/' / '//' / '^' / '%' /
                        '&' / '~' / '|' / '>>' / '<<' / '..' /
                        '<' / '<=' / '>' / '>=' / '==' / '~=' /
                        'and' / 'or'}                   -- produces string

    unop            <- {'-' / 'not' / '#' / '~'}        -- produces string

    BOOL            <- ('true')                         -> totrue
                     / ('false')                        -> tofalse

    INTEGER         <- ([0-9]+ !NAME)                   -> tonumber

    FLOAT           <- ([0-9]+'.'[0-9]+ !NAME)          -> tonumber

    STRING          <- ("'" {(!"'" .)*} "'")            -- produces string
                     / ('"' {(!'"' .)*} '"')            -- produces string

    NAME            <- (!KEYWORD POSSIBLENAME)          -- produces string

    POSSIBLENAME    <- {[a-zA-Z_][a-zA-Z0-9_]*}         -- produces string

    TYPENAME        <- ('nil' / NAME)                   -- produces string

    KEYWORD         <- ('and' / 'do' / 'else' / 'elseif' / 'end' /
                        'false' / 'for' / 'function' / 'if' /
                        'local' / 'nil' / 'not' / 'or' / 'repeat' /
                        'return' / 'then' / 'true' / 'util' / 'while' )

    COMMENT         <- ('--' (!%nl .)* %nl)

    SKIP            <- (%s / %nl / COMMENT)

]], defs, false, true)

local function errorstostr(errors)
    local msgs = {}
    for _, err in ipairs(errors) do
        local msg = string.format('%s at line %d (col %d)', err.msg, err.line,
                                  err.col)
        table.insert(msgs, msg)
    end
    return table.concat(msgs, '\n')
end

function parser.parse(input)
	local result, errors = pg.parse(input, grammar)
    if not result then
        return false, errorstostr(errors)
    else
        return result
    end
end

return parser
