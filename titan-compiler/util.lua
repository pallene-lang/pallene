local util = {}

function util.get_file_contents(filename)
    local f = assert(io.open(filename, "r"))
    local s = f:read("a")
    f:close()
    return s
end

return util
