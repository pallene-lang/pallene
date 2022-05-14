math.ln = math.log; local m = {}

function m.BottomUpTree(depth)
    if depth > 0 then
        depth = depth - 1
        local left  = m.BottomUpTree(depth)
        local right = m.BottomUpTree(depth)
        return { left, right }
    else
        return { false, false }
    end
end

function m.ItemCheck(tree)
    if tree[1] then
        return 1 + m.ItemCheck(tree[1]) + m.ItemCheck(tree[2])
    else
        return 1
    end
end

function m.Stress(mindepth, maxdepth, depth)
    local iterations = 1 << (maxdepth - depth + mindepth)
    local check = 0
    for _ = 1, iterations do
        local t = m.BottomUpTree(depth)
        check = check + m.ItemCheck(t)
    end
    return { iterations, check }
end

return m
