-- Copyright (c) 2020, The Pallene Developers
-- Pallene is licensed under the MIT license.
-- Please refer to the LICENSE and AUTHORS files for details
-- SPDX-License-Identifier: MIT

local util = require "pallene.util"

local Symtab = util.Class()
function Symtab:init()
    self.blocks = { {} }
end

function Symtab:open_block()
    table.insert(self.blocks, {})
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
    local block = self.blocks[#self.blocks]
    block[name] = symbol
    return symbol
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
