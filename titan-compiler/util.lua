local util = {}

function util.get_file_contents(filename)
    local f, err = io.open(filename, "r")
    if not f then
        return false, err
    end
    local s = f:read("a")
    f:close()
    if not s then
        return false, "unable to open file " .. filename
    else
        return s
    end
end

return util
