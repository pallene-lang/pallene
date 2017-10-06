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

function util.get_line_number(subject, pos)
	if pos == 1 then return 1,1 end
	local rest, new_lines = subject:sub(1,pos):gsub("[^\n]*\n", "")
	local col = #rest
	return new_lines + 1, col ~= 0 and col or 1
end

return util
