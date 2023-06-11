#!/usr/bin/lua

--
-- Command line parsing
--

local argparse = require "argparse"
local p = argparse(arg[0], [[
Compute the author list from the Git shortlog,
taking care to deduplicate authors with more than one e-mail]])

p:option("--at-least", "Only list authors with this many commits (def. 5)")
 :default(5)
 :convert(tonumber)
 :argname("N")

p:flag("--show-count", "Also show the commit counts")

args = p:parse()

--
-- Deduplication
--

-- Canonical => Aliases
local aliases = {
    ["Hugo Musso Gualandi"] = {
        "Hugo Gualandi",
        "hugomg"},

    ["Sérgio Queiroz"] = {
        "Sergio Queiroz" },

    ["Srijan Paul"] = {
        "srijan-paul",
        "injuly",
        "inJuly",
        "inJuly0"}
}

-- Alias => Canonical
local dedup = {}
for canonical, xs in pairs(aliases) do
    for _, x in ipairs(xs) do
        dedup[x] = canonical
    end
end

--
-- Compute the number of contributions per author
--

local gitlog = assert(io.popen("git shortlog --summary --no-merges"))

local names = {}
local total = {}
for line in gitlog:lines() do
    local count, name = string.match(line, "%s*(%d+)%s+(.*)")
    count = tonumber(count)
    name  = dedup[name] or name

    if not total[name] then
        table.insert(names, name)
        total[name] = 0
    end

    total[name] = total[name] + count
end

table.sort(names, function(a, b)
    return total[b] < total[a]
end)

gitlog:close()

--
-- Print the results
--

local date
do
    local f = assert(io.popen("date --iso-8601"))
    date = f:read("l")
    f:close()
end

io.write([[
Pallene Authors
---------------

Here we thank the many people who have contributed code to this project.
This list was last updated in ]], date, [[, using compute-authors.lua.

]])
for _, name in ipairs(names) do
    if total[name] >= args.at_least then
        if args.show_count then
            print(total[name], name)
        else
            print(name)
        end
    end
end
