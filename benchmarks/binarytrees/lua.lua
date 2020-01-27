local function BottomUpTree(depth)
    if depth > 0 then
        depth = depth - 1
        local left  = BottomUpTree(depth)
        local right = BottomUpTree(depth)
        return { left, right }
    else
        return { false, false }
    end
end

local function ItemCheck(tree)
    local t1 = tree[1]
    if t1 then
        local t2 = tree[2]
        return 1 + ItemCheck(t1) + ItemCheck(t2)
    else
        return 1
    end
end

local function Stress(mindepth, maxdepth, depth)
    local iterations = 1 << (maxdepth - depth + mindepth)
    local check = 0
    for _ = 1, iterations do
        local t = BottomUpTree(depth)
        check = check + ItemCheck(t)
    end
    return { iterations, check }
end

return {
    BottomUpTree = BottomUpTree,
    ItemCheck = ItemCheck,
    Stress = Stress,
}
