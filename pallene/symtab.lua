-- Copyright (c) 2020, The Pallene Developers
-- Pallene is licensed under the MIT license.
-- Please refer to the LICENSE and AUTHORS files for details
-- SPDX-License-Identifier: MIT

local util = require "pallene.util"

local Symtab = util.Class()
function Symtab:init()
    self.blocks = {}
    self:open_block()
end

function Symtab:open_block()
    local new_block = {}
    -- We use the '$' prefix to avoid clashes with user defined variable names.
    -- This field is used to keep track of the number of local variables in case
    -- there are too many.
    new_block["$num_locals"] =  0
    table.insert(self.blocks, new_block)
end

function Symtab:close_block()
    table.remove(self.blocks)
end

function Symtab:with_block(body, ...)
    self:open_block()
    body(...)
    self:close_block()
end


function Symtab:add_symbol(name, symbol)
    assert(#self.blocks > 0)
    local last_block = self.blocks[#self.blocks]

    if symbol._tag == "checker.Symbol.Value" then
        last_block["$num_locals"] = last_block["$num_locals"] + 1
    end

    last_block[name] = symbol
    return symbol
end

function Symtab:local_symbol_count()
    assert(#self.blocks > 0)
    return self.blocks[#self.blocks]["$num_locals"]
end

function Symtab:find_symbol(name)
    for i = #self.blocks, 1, -1 do
        local decl = self.blocks[i][name]
        if decl then
            return decl
        end
    end
    return nil
end

return Symtab
