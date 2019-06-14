local function new(x, y)
    return { x, y }
end

local function clone(x)
    return new(x[1], x[2])
end

local function conj(x)
    return new(x[1], -x[2])
end

local function add(x,y)
    return new(x[1] + y[1], x[2] + y[2])
end

local function mul(x,y)
    return new(x[1] * y[1] - x[2] * y[2], x[1] * y[2] + x[2] * y[1])
end

local function norm2(x)
    local n = mul(x, conj(x))
    return n[1]
end

local function abs(x)
--    return math.sqrt(norm2(x))
    return norm2(x)
end

return {
    new = new,
    clone = clone,
    conj = conj,
    add = add,
    mul = mul,
    norm2 = norm2,
    abs = abs,
}
