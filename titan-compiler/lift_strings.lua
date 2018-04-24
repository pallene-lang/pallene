local lift_strings = {}

local ast = require "titan-compiler.ast"
local ast_iterator = require "titan-compiler.ast_iterator"
local parser = require "titan-compiler.parser"

local lift = ast_iterator.new()

-- This optimization moves all string literals in the program into global
-- variables. So a program like the following one
--
--      function foo()
--         print("Hello")
--      end
--
-- is transformed into something like this:
--
--      local _s: string = "Hello"
--      function foo()
--          print(_s)
--      end
--
-- This is a simple way to ensure that string objects are only initialized once,
-- at module loading time. It feels a tad hacky though because this both wants
-- to run super early (so we don't need to recreate the _decl and _type fields
-- from scope analysis and type checking) and very late (closer to code
-- generation and other optimizations). Perhaps a longer term solution is
-- setting up a proper symbol table instead of relying on pointers to Toplevel
-- nodes.
--
function lift_strings.lift(filename, input)
    local prog, errors = parser.parse(filename, input)
    if not prog then return false, errors end

    local strings = {}
    lift:Program(prog, strings)

    -- Put the variables for the string literals as the first thing, so they are
    -- in scope for the whole file.
    local newprog = {}
    for _, string_tlnode in ipairs(strings) do
        table.insert(newprog, string_tlnode)
    end
    for _, tlnode in ipairs(prog) do
        table.insert(newprog, tlnode)
    end

    return newprog, errors
end

function lift:Exp(exp, strings)
    local tag = exp._tag
    if tag == ast.Exp.String then
        local loc = exp.loc

        local name = string.format("<string_literal_%d>", #strings + 1)
        local decl = ast.Decl.Decl(loc, name, ast.Type.String(loc))
        local tlnode = ast.Toplevel.Var(loc, decl, exp)

        local newexp_var = ast.Var.Name(loc, name)
        local newexp_exp = ast.Exp.Var(loc, newexp_var)

        table.insert(strings, tlnode)
        return newexp_exp
    else
        ast_iterator.Exp(self, exp, strings)
    end
end

return lift_strings
