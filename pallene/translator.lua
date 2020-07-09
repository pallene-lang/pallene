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

    local p = start_index
    local q = start_index
    while q <= stop_index do
        if input:sub(q, q) == "\n" then
            local partial = string.rep(" ", q - p)
            table.insert(self.partials, partial)
            table.insert(self.partials, "\n")
            p = q + 1
        end
        q = q + 1
    end
    local final_partial = string.rep(" ", q - p)
    table.insert(self.partials, final_partial)

    self.last_index = stop_index + 1
end

function translator.translate(input, prog_ast)
    local instance = Translator:new()

    for _, node in ipairs(prog_ast) do
        if node._tag == "ast.Toplevel.Var" then
            for _, decl in ipairs(node.decls) do
                local start = decl.col_loc.pos
                local stop = decl.end_loc.pos
                
                instance:add_whitespace(input, start, stop - 1)
            end
        end
    end
    -- Whatever characters that were not included in the partials should be added.
    instance:add_previous(input, #input)

    return table.concat(instance.partials, "")
end

return translator
