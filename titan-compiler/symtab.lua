local symtab = {}

symtab.__index = symtab

function symtab.new()
    return setmetatable({ blocks = { {} } }, symtab)
end

function symtab:open_block()
    table.insert(self.blocks, {})
end

function symtab:close_block()
    local last = self.blocks[#self.blocks]
    table.remove(self.blocks)
    return last
end

function symtab:with_block(body, ...)
    self:open_block()
    local res = body(...)
    self:close_block()
    return res
end

function symtab:add_symbol(name, decl)
    assert(#self.blocks > 0, "no blocks")
    local block = self.blocks
    block[#block][name] = decl
end

function symtab:find_symbol(name)
    local decl
    for i = #self.blocks, 1, -1 do
        decl = self.blocks[i][name]
        if decl then
            break
        end
    end
    return decl
end

function symtab:dump()
  for i, block in ipairs(self.blocks) do
    print("BLOCK " .. i .. ":")
    for name, decl in pairs(block) do
      print(name, decl)
    end
  end
end

function symtab:find_dup(name)
    return self.blocks[#self.blocks][name]
end

return symtab
