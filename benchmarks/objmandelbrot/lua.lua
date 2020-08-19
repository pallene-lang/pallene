local new, clone, conj, add, mul, norm2;
function new(x, y)
    return { x, y }
end

function clone(x)
    return new(x[1], x[2])
end

function conj(x)
    return new(x[1], -x[2])
end

function add(x, y)
    return new(x[1] + y[1], x[2] + y[2])
end

function mul(x, y)
    return new(x[1] * y[1] - x[2] * y[2], x[1] * y[2] + x[2] * y[1])
end

function norm2(x)
    local n = mul(x, conj(x))
    return n[1]
end

return {
    new = new,
    clone = clone,
    conj = conj,
    add = add,
    mul = mul,
    norm2 = norm2,
}
