-- Used in checker_spec

local values = {
    ["boolean"] = { true, false },
    ["integer"] = {
        math.mininteger, -10, -3, -2, -1, 0, 1, 2, 3, 10, math.mininteger,
    },
    ["float"] = {
        -math.huge, -2.0, -1.0, 0.0, 1.0, math.pi
    }
}

local function isnan(x)
    return x ~= x
end

local function are_same(a, b)
    return (a == b) or (isnan(a) and isnan(b))
end

local function check(f_lua, f_titan, args)
    local ok1, a = pcall(f_lua, table.unpack(args))
    local ok2, b = pcall(f_titan, table.unpack(args))
    if ok1 ~= ok2 then
        return false, string.format("lua %s but titan %s",
            (ok1 and "didn't crash" or "crashed"),
            (ok2 and "didn't crash" or "crashed"))
    end
    if ok1 and ok2 and not are_same(a, b) then
        return false, string.format("(lua: %s, titan: %s)",
            tostring(a), tostring(b))
    end
    return true
end

local function check_unop(op_str, f_lua, f_titan, typ1)
    for _, x in ipairs(values[typ1]) do
        local ok, err = check(f_lua, f_titan, {x})
        if not ok then
            error(string.format("%s %s: %s",
                op_str, tostring(x), err))
        end
    end
end

local function check_binop(op_str, f_lua, f_titan, typ1, typ2)
    for _, x in ipairs(values[typ1]) do
        for _, y in ipairs(values[typ2]) do
            local ok, err = check(f_lua, f_titan, {x, y})
            if not ok then
                error(string.format("%s %s %s: %s",
                    tostring(x), op_str, tostring(y), err))
            end
        end
    end
end

return {
    check_unop = check_unop,
    check_binop = check_binop,
}
