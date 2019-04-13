function new(x, y)
    return { re = x, im = y }
end

function clone(x)
    return new(x.re, x.im)
end

function conj(x)
    return new(x.re, -x.im)
end

function add(x,y)
    return new(x.re + y.re, x.im + y.im)
end

function mul(x,y)
    return new(x.re * y.re - x.im * y.im, x.re * y.im + x.im * y.re)
end

function norm2(x)
    return x.re * x.re + x.im * x.im
end

function abs(x)
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
