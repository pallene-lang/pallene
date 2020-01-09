local modname = arg[1]
local luaname = arg[2] or "injectLua"
local INJECT       = tonumber(arg[3]) or 0
local N            = tonumber(arg[4]) or 1000 -- or 5500

local prefix = string.match(modname, '^(.*)%.')
local luaVersion = require(prefix .. "." .. luaname)
local plnVersion = require(prefix .. ".injectPln")

local methods = {"A", "MultiplyAv", "MultiplyAtv", "MultiplyAtAv"}
for i, method in ipairs(methods) do
    local mask = 1 << (i-1)
    local injector = "inject" .. method
    if (0 == INJECT & mask) then
        plnVersion[injector](luaVersion[method])
    else
        luaVersion[injector](plnVersion[method.."_pln"])
    end
end

local res = luaVersion.Approximate(N)
print(string.format("%0.9f", res))
