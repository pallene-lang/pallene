local symtab = {}

symtab.__index = symtab

function symtab.new()
    return setmetatable({ blocks = {} }, symtab)
end

function symtab:open_block()
    table.insert(self.blocks, {})
end

function symtab:close_block()
    table.remove(self.blocks)
end

function symtab:with_block(body, ...)
    self:open_block()
    body(...)
    self:close_block()
end

function symtab:add_symbol(name, decl)
    assert(#self.blocks > 0)
    local block = self.blocks
    block[#block][name] = decl
end

function symtab:find_symbol(name)
    for i = #self.blocks, 1, -1 do
        local decl = self.blocks[i][name]
        if decl then
            return decl
        end
    end
    return nil
end

-- Determine if the given name is already being defined in the current scope.
-- This is necessary in cases where shadowing other definitions in the same
-- scope is not allowed, but shadowing outer definitions is ok. For example,
-- function argument names.
function symtab:find_dup(name)
    return self.blocks[#self.blocks][name]
end

return symtab
