-- Copyright (c) 2020, The Pallene Developers
-- Pallene is licensed under the MIT license.
-- Please refer to the LICENSE and AUTHORS files for details
-- SPDX-License-Identifier: MIT

local typedecl = require "pallene.typedecl"

local ast = {}

local function declare_type(type_name, cons)
    typedecl.declare(ast, "ast", type_name, cons)
end

declare_type("Program", {
    Program = {"tls", "type_regions", "comment_regions"}
})

declare_type("Type", {
    Nil      = {"loc"},
    Name     = {"loc", "name"},
    Array    = {"loc", "subtype"},
    Table    = {"loc", "fields"},
    Function = {"loc", "arg_types", "ret_types"},
})

declare_type("Toplevel", {
    Func      = {"loc", "visibility", "decl", "value"},
    Var       = {"loc", "visibility", "decls", "values"},
    Typealias = {"loc", "name", "type",},
    Record    = {"loc", "name", "field_decls"},
})

declare_type("Decl", {
    Decl = {"loc", "name", "type"},
})

declare_type("Stat", {
    Block  = {"loc", "stats"},
    While  = {"loc", "condition", "block"},
    Repeat = {"loc", "block", "condition"},
    If     = {"loc", "condition", "then_", "else_"},
    ForNum = {"loc", "decl", "start", "limit", "step", "block"},
    ForIn  = {"loc", "decls", "exps", "block"},
    Assign = {"loc", "vars", "exps"},
    Decl   = {"loc", "decls", "exps"},
    Call   = {"loc", "call_exp"},
    Return = {"loc", "exps"},
    Break  = {"loc"},
})

-- Things that can appear in the LHS of an assignment. For example: x, x[i], x.name
declare_type("Var", {
    Name    = {"loc", "name"},
    Bracket = {"loc", "t", "k"},
    Dot     = {"loc", "exp", "name"}
})

declare_type("Exp", {
    Nil        = {"loc"},
    Bool       = {"loc", "value"},
    Integer    = {"loc", "value"},
    Float      = {"loc", "value"},
    String     = {"loc", "value"},
    Initlist   = {"loc", "fields"},
    Lambda     = {"loc", "arg_decls", "body"},
    CallFunc   = {"loc", "exp", "args"},
    CallMethod = {"loc", "exp", "method", "args"},
    Var        = {"loc", "var"},
    Unop       = {"loc", "op", "exp"},
    Binop      = {"loc", "lhs", "op", "rhs"},
    Cast       = {"loc", "exp", "target"},
    Paren      = {"loc", "exp"},
    ExtraRet   = {"loc", "call_exp", "i"}, -- Inserted by checker.lua
    ToFloat    = {"loc", "exp"},           -- Inserted by checker.lua
})

declare_type("Field", {
    List = {"loc", "exp"},
    Rec  = {"loc", "name", "exp"},
})

--
-- note: the following functions are why we need `if type(conss) == "table"` in parser.lua
--

-- Returns a sequence containing the variable names declared by the specified
-- toplevel node.
function ast.toplevel_names(tl_node)
    local names = {}
    local tag = tl_node._tag
    if     tag == "ast.Toplevel.Func" then
        table.insert(names, tl_node.decl.name)
    elseif tag == "ast.Toplevel.Var" then
        for _, decl in ipairs(tl_node.decls) do
            table.insert(names, decl.name)
        end
    elseif tag == "ast.Toplevel.Typealias" then
        table.insert(names, tl_node.name)
    elseif tag == "ast.Toplevel.Record" then
        table.insert(names, tl_node.name)
    elseif tag == "ast.Toplevel.Builtin" then
        table.insert(names, tl_node.name)
    else
        typedecl.tag_error(tag)
    end
    return names
end

return ast
