local parser = {}

local lpeg = require "lpeglabel"
local re = require "relabel"
local inspect = require "inspect"

local ast = require "titan-compiler.ast"
local lexer = require "titan-compiler.lexer"
local syntax_errors = require "titan-compiler.syntax_errors"

--
-- Functions used by the PEG grammar
--

local defs = {}

for tokname, tokpat in pairs(lexer) do
    defs[tokname] = tokpat
end

for tag, cons in pairs(ast) do
    defs[tag] = cons
end

function defs.totrue()
    return true
end

function defs.tofalse()
    return false
end

function defs.opt(x)
    if x == "" then
        return false
    else
        return x
    end
end

function defs.boolopt(x)
    return x ~= ""
end

function defs.nil_exp(pos--[[ s ]])
    -- We can't call Exp_Nil directly in the parser because we
    -- need to drop the string capture that comes by default.
    return ast.Exp_Nil(pos)
end

function defs.number_exp(pos, n)
    if math.type(n) == "integer" then
        return ast.Exp_Integer(pos, n)
    elseif math.type(n) == "float" then
        return ast.Exp_Float(pos, n)
    else
        error("impossible")
    end
end

function defs.name_exp(pos, name)
    return ast.Exp_Var(pos, ast.Var_Name(pos, name))
end

function defs.ifstat(pos, exp, block, thens, elseopt)
    table.insert(thens, 1, ast.Then_Then(pos, exp, block))
    return ast.Stat_If(pos, thens, elseopt)
end

function defs.defstat(pos, decl, exp)
    local declstat = ast.Stat_Decl(pos, decl, exp)
    return declstat
end

function defs.fold_binop_left(pos, matches)
    local lhs = matches[1]
    for i = 2, #matches, 2 do
        local op  = matches[i]
        local rhs = matches[i+1]
        lhs = ast.Exp_Binop(pos, lhs, op, rhs)
    end
    return lhs
end

function defs.binop_concat(pos, lhs, op, rhs)
    if op then
        if rhs._tag == "Exp_Concat" then
            table.insert(rhs.exps, 1, lhs)
            return rhs
        elseif (lhs._tag == "Exp_String" or
            lhs._tag == "Exp_Integer" or
            lhs._tag == "Exp_Float") and
            (rhs._tag == "Exp_String" or
            rhs._tag == "Exp_Integer" or
            rhs._tag == "Exp_Float") then
            return ast.Exp_String(pos, lhs.value .. rhs.value)
        else
            return ast.Exp_Concat(pos, { lhs, rhs })
        end
    else
        return lhs
    end
end

function defs.binop_right(pos, lhs, op, rhs)
    if op then
        return ast.Exp_Binop(pos, lhs, op, rhs)
    else
        return lhs
    end
end

function defs.fold_unops(pos, unops, exp)
    for i = #unops, 1, -1 do
        local op = unops[i]
        exp = ast.Exp_Unop(pos, op, exp)
    end
    return exp
end

-- We represent the suffix of an expression by a function that receives the
-- base expression and returns a full expression including the suffix.

function defs.suffix_funccall(pos, args)
    return function(exp)
        return ast.Exp_Call(pos, exp, ast.Args_Func(pos, args))
    end
end

function defs.suffix_methodcall(pos, name, args)
    return function(exp)
        return ast.Exp_Call(pos, exp, ast.Args_Method(pos, name, args))
    end
end

function defs.suffix_bracket(pos, index)
    return function(exp)
        return ast.Exp_Var(pos, ast.Var_Bracket(pos, exp, index))
    end
end

function defs.suffix_dot(pos, name)
    return function(exp)
        return ast.Exp_Var(pos, ast.Var_Dot(pos, exp, name))
    end
end

function defs.fold_suffixes(exp, suffixes)
    for i = 1, #suffixes do
        local suf = suffixes[i]
        exp = suf(exp)
    end
    return exp
end

function defs.exp2var(exp)
    return exp.var
end

function defs.exp_is_var(_, pos, exp)
    if exp._tag == "Exp_Var" then
        return pos, exp
    else
        return false
    end
end

function defs.exp_is_call(_, pos, exp)
    if exp._tag == "Exp_Call" then
        return pos, exp
    else
        return false
    end
end

local grammar = re.compile([[

    program         <-  SKIP*
                        {| ( toplevelfunc
                           / toplevelvar
                           / toplevelrecord )* |} !.

    toplevelfunc    <- ({} localopt
                           FUNCTION NAME
                           LPAREN parlist RPAREN
                           COLON type
                           block END)                       -> TopLevel_Func

    toplevelvar     <- ({} localopt decl ASSIGN exp)        -> TopLevel_Var

    toplevelrecord  <- ({} RECORD NAME recordfields END)    -> TopLevel_Record

    localopt        <- (LOCAL)?                             -> boolopt

    parlist         <- {| (decl (COMMA decl)*)? |}          -- produces {Decl}

    decl            <- ({} NAME (COLON type)? -> opt)       -> Decl_Decl

    type            <- ({} NIL -> 'nil')                    -> Type_Name
                     / ({} NAME)                            -> Type_Name
                     / ({} LCURLY type RCURLY)              -> Type_Array

    recordfields    <- {| recordfield+ |}                   -- produces {Decl}

    recordfield     <- ({} NAME COLON type)                 -> Decl_Decl

    block           <- ({} {| statement* returnstat? |})    -> Stat_Block

    statement       <- (SEMICOLON)                          -- ignore
                     / (DO block END)                       -- produces Stat_Block
                     / ({} WHILE exp DO block END)          -> Stat_While
                     / ({} REPEAT block UNTIL exp)          -> Stat_Repeat
                     / ({} IF exp THEN block
                           elseifstats elseopt END)         -> ifstat
                     / ({} FOR decl
                           ASSIGN exp COMMA exp
                           (COMMA exp)? -> opt
                           DO block END)                    -> Stat_For
                     / ({} LOCAL decl ASSIGN exp)           -> defstat
                     / ({} var ASSIGN exp)                  -> Stat_Assign
                     / ({} (suffixedexp => exp_is_call))    -> Stat_Call

    elseifstats     <- {| elseifstat* |}                    -- produces {Then}

    elseifstat      <- ({} ELSEIF exp THEN block)           -> Then_Then

    elseopt         <- (ELSE block)?                        -> opt

    returnstat      <- ({} RETURN (exp? -> opt) SEMICOLON?) -> Stat_Return

    op1             <- ( OR -> 'or' )
    op2             <- ( AND -> 'and' )
    op3             <- ( EQ -> '==' / NE -> '~=' / LT -> '<' /
                         GT -> '>'  / LE -> '<=' / GE -> '>=' )
    op4             <- ( BOR -> '|' )
    op5             <- ( BXOR -> '~' )
    op6             <- ( BAND -> '&' )
    op7             <- ( SHL -> '<<' / SHR -> '>>' )
    op8             <- ( CONCAT -> '..' )
    op9             <- ( ADD -> '+' / SUB -> '-' )
    op10            <- ( MUL -> '*' / MOD -> '%%' / DIV -> '/' / IDIV -> '//' )
    unop            <- ( NOT -> 'not' / LEN -> '#' / NEG -> '-' / BNEG -> '~' )
    op12            <- ( POW -> '^' )

    exp             <- e1
    e1              <- ({} {| e2  (op1  e2 )* |})           -> fold_binop_left
    e2              <- ({} {| e3  (op2  e3 )* |})           -> fold_binop_left
    e3              <- ({} {| e4  (op3  e4 )* |})           -> fold_binop_left
    e4              <- ({} {| e5  (op4  e5 )* |})           -> fold_binop_left
    e5              <- ({} {| e6  (op5  e6 )* |})           -> fold_binop_left
    e6              <- ({} {| e7  (op6  e7 )* |})           -> fold_binop_left
    e7              <- ({} {| e8  (op7  e8 )* |})           -> fold_binop_left
    e8              <- ({}    e9  (op8  e8 )?)              -> binop_concat
    e9              <- ({} {| e10 (op9  e10)* |})           -> fold_binop_left
    e10             <- ({} {| e11 (op10 e11)* |})           -> fold_binop_left
    e11             <- ({} {| unop* |} e12)                 -> fold_unops
    e12             <- ({} suffixedexp (op12 e11)?)         -> binop_right

    suffixedexp     <- (simpleexp {| expsuffix* |})         -> fold_suffixes

    expsuffix       <- ({} funcargs)                        -> suffix_funccall
                     / ({} COLON NAME funcargs)             -> suffix_methodcall
                     / ({} LBRACKET exp RBRACKET)           -> suffix_bracket
                     / ({} DOT NAME)                        -> suffix_dot

    simpleexp       <- ({} NIL)                             -> nil_exp
                     / ({} FALSE -> tofalse)                -> Exp_Bool
                     / ({} TRUE -> totrue)                  -> Exp_Bool
                     / ({} NUMBER)                          -> number_exp
                     / ({} STRING)                          -> Exp_String
                     / (tablecons)                          -- produces Exp
                     / ({} NAME)                            -> name_exp
                     / (LPAREN exp RPAREN)                  -- produces Exp

    var             <- (suffixedexp => exp_is_var)          -> exp2var

    funcargs        <- (LPAREN explist RPAREN)              -- produces {Exp}
                     / {| tablecons |}                      -- produces {Exp}
                     / {| ({} STRING) -> Exp_String |}      -- produces {Exp}

    explist         <- {| (exp (COMMA exp)*)? |}            -- produces {Exp}

    tablecons       <- ({} LCURLY {| fieldlist? |} RCURLY)  -> Exp_Table

    fieldlist       <- (exp (fieldsep exp)* fieldsep?)      -- produces Exp...

    fieldsep        <- SEMICOLON / COMMA

    -- Create new rules for all our tokens, for the whitespace-skipping magic
    -- Currently done by hand but this is something that parser-gen should be
    -- able to do for us.

    SKIP            <- (%SPACE / %COMMENT)

    AND             <- %AND SKIP*
    BREAK           <- %BREAK SKIP*
    DO              <- %DO SKIP*
    ELSE            <- %ELSE SKIP*
    ELSEIF          <- %ELSEIF SKIP*
    END             <- %END SKIP*
    FALSE           <- %FALSE SKIP*
    FOR             <- %FOR SKIP*
    FUNCTION        <- %FUNCTION SKIP*
    GOTO            <- %GOTO SKIP*
    IF              <- %IF SKIP*
    IN              <- %IN SKIP*
    LOCAL           <- %LOCAL SKIP*
    NIL             <- %NIL SKIP*
    NOT             <- %NOT SKIP*
    OR              <- %OR SKIP*
    RECORD          <- %RECORD SKIP*
    REPEAT          <- %REPEAT SKIP*
    RETURN          <- %RETURN SKIP*
    THEN            <- %THEN SKIP*
    TRUE            <- %TRUE SKIP*
    UNTIL           <- %UNTIL SKIP*
    WHILE           <- %WHILE SKIP*

    ADD             <- %ADD SKIP*
    SUB             <- %SUB SKIP*
    MUL             <- %MUL SKIP*
    MOD             <- %MOD SKIP*
    DIV             <- %DIV SKIP*
    IDIV            <- %IDIV SKIP*
    POW             <- %POW SKIP*
    LEN             <- %LEN SKIP*
    BAND            <- %BAND SKIP*
    BXOR            <- %BXOR SKIP*
    BOR             <- %BOR SKIP*
    SHL             <- %SHL SKIP*
    SHR             <- %SHR SKIP*
    CONCAT          <- %CONCAT SKIP*
    EQ              <- %EQ SKIP*
    LT              <- %LT SKIP*
    GT              <- %GT SKIP*
    NE              <- %NE SKIP*
    LE              <- %LE SKIP*
    GE              <- %GE SKIP*
    ASSIGN          <- %ASSIGN SKIP*
    LPAREN          <- %LPAREN SKIP*
    RPAREN          <- %RPAREN SKIP*
    LBRACKET        <- %LBRACKET SKIP*
    RBRACKET        <- %RBRACKET SKIP*
    LCURLY          <- %LCURLY SKIP*
    RCURLY          <- %RCURLY SKIP*
    SEMICOLON       <- %SEMICOLON SKIP*
    COMMA           <- %COMMA SKIP*
    DOT             <- %DOT SKIP*
    DOTS            <- %DOTS SKIP*
    DBLCOLON        <- %DBLCOLON SKIP*
    COLON           <- %COLON SKIP*

    NUMBER          <- %NUMBER SKIP*
    STRING          <- %STRING SKIP*
    NAME            <- %NAME SKIP*

    -- Synonyms

    NEG             <- SUB
    BNEG            <- BXOR

]], defs)

function parser.parse(input)
    local ast, errnum, suffix = grammar:match(input)
    if ast then
        return ast
    else
        local pos = #input - #suffix + 1
        local line, col = re.calcline(input, pos)
        local label = syntax_errors.int_to_label[errnum]
        return false, { line=line, col=col, label=label }
    end
end

function parser.error_to_string(err, filename)
    return string.format("%s:%d:%d: syntax error: %s",
            filename, err.line, err.col, syntax_errors.label_to_msg[err.label])
end

function parser.pretty_print_ast(ast)
    return inspect(ast, {
        process = function(item, path)
            if path[#path] ~= inspect.METATABLE then
                return item
            end
        end
    })
end

return parser
