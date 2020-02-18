-- Copyright (c) 2020, The Pallene Developers
-- Pallene is licensed under the MIT license.
-- Please refer to the LICENSE and AUTHORS files for details
-- SPDX-License-Identifier: MIT

local typedecl = require "pallene.typedecl"

local ast = {}

local function declare_type(type_name, cons)
    typedecl.declare(ast, "ast", type_name, cons)
end

declare_type("Type", {
    Nil      = {"loc"},
    Boolean  = {"loc"},
    Integer  = {"loc"},
    Float    = {"loc"},
    String   = {"loc"},
    Any      = {"loc"},
    Name     = {"loc", "name"},
    Array    = {"loc", "subtype"},
    Table    = {"loc", "fields"},
    Function = {"loc", "arg_types", "ret_types"},
})

declare_type("Toplevel", {
    Func      = {"loc", "is_local", "decl", "value"},
    Var       = {"loc", "decl", "value"},
    Typealias = {"loc", "name", "type"},
    Record    = {"loc", "name", "field_decls"},
    Import    = {"loc", "local_name", "mod_name"},
    Builtin   = {"loc", "name"},
})

declare_type("Decl", {
    Decl = {"loc", "name", "type"},
})

declare_type("Stat", {
    Block  = {"loc", "stats"},
    While  = {"loc", "condition", "block"},
    Repeat = {"loc", "block", "condition"},
    If     = {"loc", "condition", "then_", "else_"},
    For    = {"loc", "decl", "start", "limit", "step", "block"},
    Assign = {"loc", "vars", "exps"},
    Decl   = {"loc", "decls", "exps"},
    Call   = {"loc", "call_exp"},
    Return = {"loc", "exps"},
    Break  = {"loc"},
})

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
    Lambda     = {"loc", "arg_names", "body"},
    CallFunc   = {"loc", "exp", "args"},
    CallMethod = {"loc", "exp", "method", "args"},
    Var        = {"loc", "var"},
    Unop       = {"loc", "op", "exp"},
    Concat     = {"loc", "exps"},
    Binop      = {"loc", "lhs", "op", "rhs"},
    Cast       = {"loc", "exp", "target"}

})

declare_type("Field", {
    Field = {"loc", "name", "exp"},
})

--
-- note: the following functions are why we need `if type(conss) == "table"`
-- in parser.lua
--

-- Return the variable name declared by a given toplevel node
function ast.toplevel_name(tl_node)
    local tag = tl_node._tag
    if     tag == "ast.Toplevel.Func" then
        return tl_node.decl.name
    elseif tag == "ast.Toplevel.Var" then
        return tl_node.decl.name
    elseif tag == "ast.Toplevel.Typealias" then
        return tl_node.name
    elseif tag == "ast.Toplevel.Record" then
        return tl_node.name
    elseif tag == "ast.Toplevel.Import" then
        return tl_node.localname
    elseif tag == "ast.Toplevel.Builtin" then
        return tl_node.name
    else
        error("impossible")
    end
end

return ast
