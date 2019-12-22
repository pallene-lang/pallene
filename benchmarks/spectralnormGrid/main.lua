local spectralnorm = require(arg[1])
local N            = tonumber(arg[2]) or 1000 -- or 5500
local INJECT       = tonumber(arg[3]) or 0

local prefix = string.match(arg[1], '^(.*)%.')
if arg[1] == prefix .. ".inject" then
    local luaversion = require(prefix .. ".lua")
    local palleneversion = spectralnorm
    local methods = {"A", "MultiplyAv", "MultiplyAtv", "MultiplyAtAv"}
    for i, method in ipairs(methods) do
        local mask = 1 << (i-1)
        local injector = "inject" .. method
        if (0 == INJECT & mask) then
            print(method, "lua")
            palleneversion[injector](luaversion[method])
        else
            print(method, "pallene")
            luaversion[injector](palleneversion[method.."_pln"])
        end
    end
end

print("===")

local res = spectralnorm.Approximate(N)
print(string.format("%0.9f", res))
