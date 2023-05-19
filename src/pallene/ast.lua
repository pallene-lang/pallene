-- Copyright (c) 2020, The Pallene Developers
-- Pallene is licensed under the MIT license.
-- Please refer to the LICENSE and AUTHORS files for details
-- SPDX-License-Identifier: MIT

local tagged_union = require "pallene.tagged_union"

local ast = {}

local function declare_type(type_name, cons)
    tagged_union.declare(ast, "ast", type_name, cons)
end

declare_type("Program", {
    Program = {"loc", "ret_loc", "module_name", "tls", "type_regions", "comment_regions"}
})

declare_type("Type", {
    Nil      = {"loc"},
    Name     = {"loc", "name"},
    Array    = {"loc", "subtype"},
    Table    = {"loc", "fields"},
    Function = {"loc", "arg_types", "ret_types"},
})

declare_type("Toplevel", {
    Stats     = {"loc", "stats"},
    Typealias = {"loc", "name", "type",},
    Record    = {"loc", "name", "field_decls"},
})

declare_type("Decl", {
    Decl = {"loc", "name", "type"},
})

declare_type("Stat", {
    Block     = {"loc", "stats"},
    While     = {"loc", "condition", "block"},
    Repeat    = {"loc", "block", "condition"},
    If        = {"loc", "condition", "then_", "else_"},
    ForNum    = {"loc", "decl", "start", "limit", "step", "block"},
    ForIn     = {"loc", "decls", "exps", "block"},
    Assign    = {"loc", "vars", "exps"},
    Decl      = {"loc", "decls", "exps"},
    Call      = {"loc", "call_exp"},
    Return    = {"loc", "exps"},
    Break     = {"loc"},
    Functions = {"loc", "declared_names", "funcs"}, -- For mutual recursion (see parser.lua)
})

declare_type("FuncStat", {
    FuncStat = {"loc", "module", "name", "method", "ret_types", "value"},
})

-- Things that can appear in the LHS of an assignment. For example: x, x[i], x.name
declare_type("Var", {
    Name    = {"loc", "name"},
    Bracket = {"loc", "t", "k"},
    Dot     = {"loc", "exp", "name"}
})

declare_type("Exp", {
    Nil           = {"loc"},
    Bool          = {"loc", "value"},
    Integer       = {"loc", "value"},
    Float         = {"loc", "value"},
    String        = {"loc", "value"},
    InitList      = {"loc", "fields"},
    Lambda        = {"loc", "arg_decls", "body"},
    CallFunc      = {"loc", "exp", "args"},
    CallMethod    = {"loc", "exp", "method", "args"},
    Var           = {"loc", "var"},
    Unop          = {"loc", "op", "exp"},
    Binop         = {"loc", "lhs", "op", "rhs"},
    Cast          = {"loc", "exp", "target"},
    Paren         = {"loc", "exp"},
    ExtraRet      = {"loc", "call_exp", "i"}, -- Inserted by typechecker.lua
    ToFloat       = {"loc", "exp"},           -- Inserted by checker.lua
    UpvalueRecord = {"loc"},                  -- Inserted by assignment_conversion.lua
})

declare_type("Field", {
    List = {"loc", "exp"},
    Rec  = {"loc", "name", "exp"},
})

return ast
