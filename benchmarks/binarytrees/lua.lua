local BottomUpTree, ItemCheck, Stress;
function BottomUpTree(depth)
    if depth > 0 then
        depth = depth - 1
        local left  = BottomUpTree(depth)
        local right = BottomUpTree(depth)
        return { left, right }
    else
        return { false, false }
    end
end

function ItemCheck(tree)
    if tree[1] then
        return 1 + ItemCheck(tree[1]) + ItemCheck(tree[2])
    else
        return 1
    end
end

function Stress(mindepth, maxdepth, depth)
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
