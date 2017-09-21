local parser = {}

local pg = require 'parser-gen'
local peg = require 'peg-parser'
local inspect = require 'inspect'

local ast = require 'titan-compiler.ast'
local lexer = require 'titan-compiler.lexer'

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

function defs.tonil()
    return nil
end

function defs.totrue()
    return true
end

function defs.tofalse()
    return false
end

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

function defs.name_exp(name)
    return ast.Exp_Var(ast.Var_Name(name))
end

function defs.ifstat(exp, block, thens, elseopt)
    table.insert(thens, 1, ast.Then_Then(exp, block)) 
    return ast.Stat_If(thens, elseopt)
end

function defs.defstat(decl, exp)
    local declstat = ast.Stat_Decl(decl)
    local assign = ast.Stat_Assign(ast.Var_Name(decl.name), exp)
    return declstat, assign
end

function defs.fold_binop_left(matches)
    local lhs = matches[1]
    for i = 2, #matches, 2 do
        local op  = matches[i]
        local rhs = matches[i+1]
        lhs = ast.Exp_Binop(lhs, op, rhs)
    end
    return lhs
end

function defs.binop_right(lhs, op, rhs)
    if op then
        return ast.Exp_Binop(lhs, op, rhs)
    else
        return lhs
    end
end

function defs.fold_unops(unops, exp)
    for i = #unops, 1, -1 do
        local op = unops[i]
        exp = ast.Exp_Unop(op, exp)
    end
    return exp
end

-- We represent the suffix of an expression by a function that receives the
-- base expression and returns a full expression including the suffix.

function defs.suffix_funccall(args)
    return function(exp)
        return ast.Exp_Call(exp, ast.Args_Func(args))
    end
end

function defs.suffix_methodcall(name, args)
    return function(exp)
        return ast.Exp_Call(exp, ast.Args_Method(name, args))
    end
end

function defs.suffix_index(index)
    return function(exp)
        return ast.Exp_Var( ast.Var_Index(exp, index) )
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
    if exp._tag == 'Exp_Var' then
        return pos, exp
    else
        return false
    end
end

function defs.exp_is_call(_, pos, exp)
    if exp._tag == 'Exp_Call' then
        return pos, exp
    else
        return false
    end
end

-- Add libraries to defs

local grammar = pg.compile([[

    program         <- {| (toplevelfunc / toplevelvar)* |} !.

    toplevelfunc    <- (localopt
                        FUNCTION NAME
                        LPAREN parlist RPAREN
                        COLON type
                        block END)                      -> TopLevel_Func

    toplevelvar     <- (localopt decl ASSIGN exp)       -> TopLevel_Var

    localopt        <- (LOCAL)?                         -> boolopt

    parlist         <- {| (decl (COMMA decl)*)? |}      -- produces {Decl}

    decl            <- (NAME (COLON type)? -> opt)      -> Decl_Decl

    type            <- (NIL -> 'nil')                   -> Type_Basic
                     / (NAME)                           -> Type_Basic
                     / (LCURLY type RCURLY)             -> Type_Array

    block           <- {| statement* returnstat? |}     -- produces {Stat}

    statement       <- (SEMICOLON)                      -- ignore
                     / (DO block END)                   -> Stat_Block
                     / (WHILE exp DO block END)         -> Stat_While
                     / (REPEAT block UNTIL exp)         -> Stat_Repeat
                     / (IF exp THEN block
                        elseifstats elseopt END)        -> ifstat
                     / (FOR NAME ASSIGN exp COMMA exp
                        (COMMA exp)? -> opt
                        DO block END)                   -> Stat_For
                     / (LOCAL decl ASSIGN exp)          -> defstat
                     / (var ASSIGN exp)                 -> Stat_Assign
                     / (suffixedexp => exp_is_call)     -> Stat_Call

    elseifstats     <- {| elseifstat* |}                -- produces {Then}

    elseifstat      <- (ELSEIF exp THEN block)          -> Then_Then

    elseopt         <- (ELSE block)?                    -> opt

    returnstat      <- (RETURN (exp? -> opt) SEMICOLON?)-> Stat_Return

    op1             <- { OR }
    op2             <- { AND }
    op3             <- { EQ / NE / LT / GT / LE / GE }
    op4             <- { BOR }
    op5             <- { BXOR }
    op6             <- { BAND }
    op7             <- { SHL / SHR }
    op8             <- { CONCAT }
    op9             <- { ADD / SUB }
    op10            <- { MUL / MOD / DIV / IDIV }
    unop            <- { NOT / LEN / NEG / BNEG }
    op12            <- { POW }

    exp             <- e1
    e1              <- {| e2  (op1  e2 )* |}            -> fold_binop_left
    e2              <- {| e3  (op2  e3 )* |}            -> fold_binop_left
    e3              <- {| e4  (op3  e4 )* |}            -> fold_binop_left
    e4              <- {| e5  (op4  e5 )* |}            -> fold_binop_left
    e5              <- {| e6  (op5  e6 )* |}            -> fold_binop_left
    e6              <- {| e7  (op6  e7 )* |}            -> fold_binop_left
    e7              <- {| e8  (op7  e8 )* |}            -> fold_binop_left
    e8              <- (  e9  (op8  e8 )?  )            -> binop_right
    e9              <- {| e10 (op9  e10)* |}            -> fold_binop_left
    e10             <- {| e11 (op10 e11)* |}            -> fold_binop_left
    e11             <- (  {| unop* |} e12  )            -> fold_unops
    e12             <- (  suffixedexp (op12 e11)? )     -> binop_right

    suffixedexp     <- ( simpleexp {| expsuffix* |} )   -> fold_suffixes

    expsuffix       <- (funcargs)                       -> suffix_funccall
                     / (COLON NAME funcargs)            -> suffix_methodcall
                     / (LBRACKET exp RBRACKET)          -> suffix_index

    simpleexp       <- (NIL -> tonil)                   -> Exp_Value
                     / (FALSE -> tofalse)               -> Exp_Value
                     / (TRUE -> totrue)                 -> Exp_Value
                     / (NUMBER)                         -> Exp_Value
                     / (STRING)                         -> Exp_Value
                     / (tablecons)                      -- produces Exp
                     / (NAME)                           -> name_exp
                     / (LPAREN exp RPAREN)              -- produces Exp

    var             <- (suffixedexp => exp_is_var)      -> exp2var

    funcargs        <- (LPAREN explist RPAREN)          -- produces {Exp}
                     / {| tablecons |}                  -- produces {Exp}
                     / {| STRING -> Exp_Value |}        -- produces {Exp}

    explist         <- {| (exp (COMMA exp)*)? |}        -- produces {Exp}

    tablecons       <- (LCURLY {| fieldlist? |} RCURLY) -> Exp_Table

    fieldlist       <- (exp (fieldsep exp)* fieldsep?)  -- produces Exp...

    fieldsep        <- SEMICOLON / COMMA

    -- Create new rules for all our tokens, so parser-gen can
    -- work its whitespace-skipping magic
    
    AND             <- %AND
    BREAK           <- %BREAK
    DO              <- %DO
    ELSE            <- %ELSE
    ELSEIF          <- %ELSEIF
    END             <- %END
    FOR             <- %FOR
    FALSE           <- %FALSE
    FUNCTION        <- %FUNCTION
    GOTO            <- %GOTO
    IF              <- %IF
    IN              <- %IN
    LOCAL           <- %LOCAL
    NIL             <- %NIL
    NOT             <- %NOT
    OR              <- %OR
    REPEAT          <- %REPEAT
    RETURN          <- %RETURN
    THEN            <- %THEN
    TRUE            <- %TRUE
    UNTIL           <- %UNTIL
    WHILE           <- %WHILE

    ADD             <- %ADD
    SUB             <- %SUB
    MUL             <- %MUL
    MOD             <- %MOD
    DIV             <- %DIV
    IDIV            <- %IDIV
    POW             <- %POW
    LEN             <- %LEN
    BAND            <- %BAND
    BXOR            <- %BXOR
    BOR             <- %BOR
    SHL             <- %SHL
    SHR             <- %SHR
    CONCAT          <- %CONCAT
    EQ              <- %EQ
    LT              <- %LT
    GT              <- %GT
    NE              <- %NE
    LE              <- %LE
    GE              <- %GE
    ASSIGN          <- %ASSIGN
    LPAREN          <- %LPAREN
    RPAREN          <- %RPAREN
    LBRACKET        <- %LBRACKET
    RBRACKET        <- %RBRACKET
    LCURLY          <- %LCURLY
    RCURLY          <- %RCURLY
    SEMICOLON       <- %SEMICOLON
    COMMA           <- %COMMA
    DOT             <- %DOT
    DOTS            <- %DOTS
    DBLCOLON        <- %DBLCOLON
    COLON           <- %COLON

    NUMBER          <- %NUMBER
    STRING          <- %STRING
    NAME            <- %NAME

    SKIP            <- (%SPACE / %COMMENT)

    -- Synonyms

    NEG             <- SUB
    BNEG            <- BXOR

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
