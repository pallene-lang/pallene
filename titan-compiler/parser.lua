local parser = {}

local re = require "relabel"
local inspect = require "inspect"

local ast = require "titan-compiler.ast"
local lexer = require "titan-compiler.lexer"
local syntax_errors = require "titan-compiler.syntax_errors"
local util = require "titan-compiler.util"

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

function defs.rettypeopt(pos, x)
    if not x then
        -- When possible, we should change this default to the empty list
        -- or infer the return type.
        return { ast.TypeName(pos, "nil") }
    else
        return x
    end
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

function defs.nil_exp(pos--[[, s ]])
    -- We can't call ast.ExpNil directly in the parser because we
    -- need to drop the string capture that comes in the second argument.
    return ast.ExpNil(pos)
end

function defs.number_exp(pos, n)
    if math.type(n) == "integer" then
        return ast.ExpInteger(pos, n)
    elseif math.type(n) == "float" then
        return ast.ExpFloat(pos, n)
    else
        error("impossible")
    end
end

function defs.name_exp(pos, name)
    return ast.ExpVar(pos, ast.VarName(pos, name))
end

function defs.ifstat(pos, exp, block, thens, elseopt)
    table.insert(thens, 1, ast.Then(pos, exp, block))
    return ast.StatIf(pos, thens, elseopt)
end

function defs.fold_binop_left(pos, matches)
    local lhs = matches[1]
    for i = 2, #matches, 2 do
        local op  = matches[i]
        local rhs = matches[i+1]
        lhs = ast.ExpBinop(pos, lhs, op, rhs)
    end
    return lhs
end

-- Should this go on a separate constant propagation pass?
function defs.binop_concat(pos, lhs, op, rhs)
    if op then
        if rhs._tag == "AstExpConcat" then
            table.insert(rhs.exps, 1, lhs)
            return rhs
        elseif (lhs._tag == "AstExpString" or
            lhs._tag == "AstExpInteger" or
            lhs._tag == "AstExpFloat") and
            (rhs._tag == "AstExpString" or
            rhs._tag == "AstExpInteger" or
            rhs._tag == "AstExpFloat") then
            return ast.ExpString(pos, lhs.value .. rhs.value)
        else
            return ast.ExpConcat(pos, { lhs, rhs })
        end
    else
        return lhs
    end
end

function defs.binop_right(pos, lhs, op, rhs)
    if op then
        return ast.ExpBinop(pos, lhs, op, rhs)
    else
        return lhs
    end
end

function defs.fold_unops(pos, unops, exp)
    for i = #unops, 1, -1 do
        local op = unops[i]
        exp = ast.ExpUnop(pos, op, exp)
    end
    return exp
end

-- We represent the suffix of an expression by a function that receives the
-- base expression and returns a full expression including the suffix.

function defs.suffix_funccall(pos, args)
    return function(exp)
        return ast.ExpCall(pos, exp, ast.ArgsFunc(pos, args))
    end
end

function defs.suffix_methodcall(pos, name, args)
    return function(exp)
        return ast.ExpCall(pos, exp, ast.ArgsMethod(pos, name, args))
    end
end

function defs.suffix_bracket(pos, index)
    return function(exp)
        return ast.ExpVar(pos, ast.VarBracket(pos, exp, index))
    end
end

function defs.suffix_dot(pos, name)
    return function(exp)
        return ast.ExpVar(pos, ast.VarDot(pos, exp, name))
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
    if exp._tag == "AstExpVar" then
        return pos, exp
    else
        return false
    end
end

function defs.exp_is_call(_, pos, exp)
    if exp._tag == "AstExpCall" then
        return pos, exp
    else
        return false
    end
end

re.setlabels(syntax_errors.label_to_int)

local grammar = re.compile([[

    program         <-  SKIP*
                        {| ( toplevelfunc
                           / toplevelvar
                           / toplevelrecord
                           / import )* |} !.

    toplevelfunc    <- ({} localopt
                           FUNCTION (NAME / %{NameFunc})
                           (LPAREN / %{LParPList}) paramlist (RPAREN / %{RParPList})
                           rettypeopt
                           block (END / %{EndFunc}))             -> TopLevelFunc

    toplevelvar     <- ({} localopt decl (ASSIGN / %{AssignVar})
                           !IMPORT (exp / %{ExpVarDec}))         -> TopLevelVar

    toplevelrecord  <- ({} RECORD (NAME / %{NameRecord}) (recordfields / %{FieldRecord})
                           (END / %{EndRecord}))                 -> TopLevelRecord

    localopt        <- (LOCAL)?                                  -> boolopt

    import          <- ({} LOCAL (NAME / %{NameImport}) (ASSIGN / %{AssignImport})
                          (IMPORT / %{ImportImport})
                          (LPAREN (STRING / %{StringLParImport}) (RPAREN / %{RParImport}) /
                          (STRING / %{StringImport})))           -> TopLevelImport

    rettypeopt      <- ({} (COLON (rettype / %{TypeFunc}))?)     -> rettypeopt

    paramlist       <- {| (param (COMMA
                            (param / %{DeclParList}))*)? |}      -- produces {Decl}

    param           <- ({} NAME (COLON / %{ParamSemicolon})
                                (type / %{TypeDecl}))           -> Decl

    decl            <- ({} NAME (COLON
                            (type / %{TypeDecl}))? -> opt)       -> Decl

    simpletype      <- ({} NIL -> 'nil')                         -> TypeName
                     / ({} NAME)                                 -> TypeName
                     / ({} LCURLY (type / %{TypeType})
                                  (RCURLY / %{RCurlyType}))      -> TypeArray

    typelist        <- ( LPAREN
                         {| (type (COMMA (type / %{TypelistType}))*)? |}
                         (RPAREN / %{RParenTypelist}) )          -- produces {Type}

    rettype         <- {| ({} typelist RARROW
                            (rettype / %{TypeReturnTypes})) -> TypeFunction |}
                     / {| ({} {| simpletype |} RARROW
                            (rettype / %{TypeReturnTypes})) -> TypeFunction |}
                     / typelist
                     / {| simpletype |}

    type            <- ({} typelist RARROW
                           (rettype / %{TypeReturnTypes}))       -> TypeFunction
                     / ({} {| simpletype |} RARROW
                           (rettype / %{TypeReturnTypes}))       -> TypeFunction
                     / simpletype

    recordfields    <- {| recordfield+ |}                        -- produces {Decl}

    recordfield     <- ({} NAME
                           (COLON / %{ColonRecordField})
                           (type / %{TypeRecordField})
                           SEMICOLON?)                      -> Decl

    block           <- ({} {| statement* returnstat? |})         -> StatBlock

    statement       <- (SEMICOLON)                               -- ignore
                     / (DO block (END / %{EndBlock}))            -- produces StatBlock
                     / ({} WHILE (exp / %{ExpWhile}) (DO / %{DoWhile})
                                 block (END / %{EndWhile}))      -> StatWhile
                     / ({} REPEAT block (UNTIL / %{UntilRepeat})
                                      (exp / %{ExpRepeat}))      -> StatRepeat
                     / ({} IF (exp / %{ExpIf}) (THEN / %{ThenIf}) block
                           elseifstats elseopt
                           (END / %{EndIf}))                     -> ifstat
                     / ({} FOR (decl / %{DeclFor})
                           (ASSIGN / %{AssignFor}) (exp / %{Exp1For})
                           (COMMA / %{CommaFor}) (exp / %{Exp2For})
                           (COMMA (exp / %{Exp3For}))? -> opt
                           (DO / %{DoFor}) block
                           (END / %{EndFor}))                    -> StatFor
                     / ({} LOCAL (decl / %{DeclLocal}) (ASSIGN / %{AssignLocal})
                                 (exp / %{ExpLocal}))            -> StatDecl
                     / ({} var (ASSIGN / %{AssignAssign})
                               (exp / %{ExpAssign}))             -> StatAssign
                     / &(exp ASSIGN) %{ExpAssign}
                     / ({} (suffixedexp => exp_is_call))         -> StatCall
                     / &exp %{ExpStat}

    elseifstats     <- {| elseifstat* |}                         -- produces {Then}

    elseifstat      <- ({} ELSEIF (exp / %{ExpElseIf})
                           (THEN / %{ThenElseIf}) block)         -> Then

    elseopt         <- (ELSE block)?                             -> opt

    returnstat      <- ({} RETURN (exp? -> opt) SEMICOLON?)      -> StatReturn

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
    e1              <- ({} {| e2  (op1  (e2 / %{OpExp}))* |})    -> fold_binop_left
    e2              <- ({} {| e3  (op2  (e3 / %{OpExp}))* |})    -> fold_binop_left
    e3              <- ({} {| e4  (op3  (e4 / %{OpExp}))* |})    -> fold_binop_left
    e4              <- ({} {| e5  (op4  (e5 / %{OpExp}))* |})    -> fold_binop_left
    e5              <- ({} {| e6  (op5  (e6 / %{OpExp}))* |})    -> fold_binop_left
    e6              <- ({} {| e7  (op6  (e7 / %{OpExp}))* |})    -> fold_binop_left
    e7              <- ({} {| e8  (op7  (e8 / %{OpExp}))* |})    -> fold_binop_left
    e8              <- ({}    e9  (op8  (e8 / %{OpExp}))?)       -> binop_concat
    e9              <- ({} {| e10 (op9  (e10 / %{OpExp}))* |})   -> fold_binop_left
    e10             <- ({} {| e11 (op10 (e11 / %{OpExp}))* |})   -> fold_binop_left
    e11             <- ({} {| unop* |}  e12)                     -> fold_unops
    e12             <- ({} castexp (op12 (e11 / %{OpExp}))?)   -> binop_right

    suffixedexp     <- (prefixexp {| expsuffix+ |})              -> fold_suffixes

    expsuffix       <- ({} funcargs)                             -> suffix_funccall
                     / ({} COLON (NAME / %{NameColonExpSuf})
                                 (funcargs / %{FuncArgsExpSuf})) -> suffix_methodcall
                     / ({} LBRACKET (exp / %{ExpExpSuf})
                                (RBRACKET / %{RBracketExpSuf}))  -> suffix_bracket
                     / ({} DOT (NAME / %{NameDotExpSuf}))        -> suffix_dot

    prefixexp       <- ({} NAME)                                 -> name_exp
                     / (LPAREN (exp / %{ExpSimpleExp})
                               (RPAREN / %{RParSimpleExp}))      -- produces Exp


    castexp         <- ({} simpleexp AS
                            (type / %{CastMissingType}))         -> ExpCast
                     / simpleexp                                 -- produces Exp

    simpleexp       <- ({} NIL)                                  -> nil_exp
                     / ({} FALSE -> tofalse)                     -> ExpBool
                     / ({} TRUE -> totrue)                       -> ExpBool
                     / ({} NUMBER)                               -> number_exp
                     / ({} STRING)                               -> ExpString
                     / initlist                                  -- produces Exp
                     / suffixedexp                               -- produces Exp
                     / prefixexp                                 -- produces Exp

    var             <- (suffixedexp => exp_is_var)               -> exp2var
                     / ({} NAME !expsuffix)                      -> name_exp -> exp2var

    funcargs        <- (LPAREN explist
                               (RPAREN / %{RParFuncArgs}))       -- produces {Exp}
                     / {| initlist |}                            -- produces {Exp}
                     / {| ({} STRING) -> ExpString |}            -- produces {Exp}

    explist         <- {| (exp (COMMA (exp / %{ExpExpList}))*)? |} -- produces {Exp}

    initlist        <- ({} LCURLY {| fieldlist? |}
                                  (RCURLY / %{RCurlyInitList})) -> ExpInitList

    fieldlist       <- (field
                        (fieldsep
                         (field /
                          !RCURLY %{ExpFieldList}))*
                        fieldsep?)                          -- produces Field...

    field           <- ({} (NAME ASSIGN)? -> opt exp)       -> Field

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
    IMPORT          <- %IMPORT SKIP*
    AS              <- %AS SKIP*

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
    RARROW          <- %RARROW SKIP*

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
        local line, col = util.get_line_number(input, pos)
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
