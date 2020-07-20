-- Copyright (c) 2020, The Pallene Developers
-- Pallene is licensed under the MIT license.
-- Please refer to the LICENSE and AUTHORS files for details
-- SPDX-License-Identifier: MIT

local util = require "pallene.util"

local translator = {}

local Translator = util.Class()

function Translator:init()
    self.last_index = 1
    self.partials = {}
    return self
end

function Translator:add_previous(input, stop_index)
    local partial = input:sub(self.last_index, stop_index)
    table.insert(self.partials, partial)
    self.last_index = stop_index + 1
end

function Translator:add_whitespace(input, start_index, stop_index)
    self:add_previous(input, start_index - 1)

    local region = input:sub(start_index, stop_index)
    local partial = region:gsub("%S", " ")
    table.insert(self.partials, partial)

    self.last_index = stop_index + 1
end

function translator.translate(input, prog_ast)
    local instance = Translator:new()

    for _, node in ipairs(prog_ast) do
        if node._tag == "ast.Toplevel.Var" then
            for _, decl in ipairs(node.decls) do
                if decl.type then
                    -- Remove the colon but retain any adjacent comment to the right.
                    instance:add_whitespace(input, decl.col_loc.pos, decl.col_loc.pos)
                    -- Remove the type annotation but exclude the next token.
                    instance:add_whitespace(input, decl.type.loc.pos, decl.end_loc.pos - 1)
                end
            end
        elseif node._tag == "ast.Toplevel.Func" then
            -- Remove type annotations from function parameters.
            for _, arg_decl in ipairs(node.value.arg_decls) do
                -- Type annotations are mandatory for function parameters.
                -- Remove the colon but retain any adjacent comment to the right.
                instance:add_whitespace(input, arg_decl.col_loc.pos, arg_decl.col_loc.pos)
                -- Remove the type annotation but exclude the next token.
                instance:add_whitespace(input, arg_decl.type.loc.pos, arg_decl.end_loc.pos - 1)
            end

            -- Remove type annotations from local declarations.
            for _, statement in ipairs(node.value.body.stats) do
                if statement._tag == "ast.Stat.Decl" then
                    for _, decl in ipairs(statement.decls) do
                        if decl.type then
                            -- Remove the colon but retain any adjacent comment to the right.
                            instance:add_whitespace(input, decl.col_loc.pos, decl.col_loc.pos)
                            -- Remove the type annotation but exclude the next token.
                            instance:add_whitespace(input, decl.type.loc.pos, decl.end_loc.pos - 1)
                        end
                    end
                end
            end
        end
    end
    -- Whatever characters that were not included in the partials should be added.
    instance:add_previous(input, #input)

    return table.concat(instance.partials, "")
end

return translator
