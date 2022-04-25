#!/bin/lua

-- CORELIB CODE GENERATION
-- =======================
--
-- This script generates the corelib C files. We must run this again whenever change the corelib, or
-- whenever a new Lua version comes out.

local CORELIB_VERSION = 1001 -- Don't forget to bump this

local LUA_RELEASE_STR = "5.4.4" -- see lua.h, LUA_RELEASE
local LUA_RELEASE_NUM = 50404   -- see lua.h, LUA_VERSION_RELEASE_NUM

local exported_fns = {
    "pallene_tag_name",
    "pallene_runtime_tag_check_error",
    "pallene_runtime_arity_error",
    "pallene_runtime_divide_by_zero_error",
    "pallene_runtime_mod_by_zero_error",
    "pallene_runtime_number_to_integer_error",
    "pallene_runtime_array_metatable_error",
    "pallene_string_concatN",
    "pallene_grow_array",
    "pallene_io_write",
    "pallene_string_char",
    "pallene_string_sub",
    "pallene_l_strcmp",
    "pallene_type_builtin",
    "pallene_tostring",

    "luaC_step",
    "luaC_barrierback_",
    "luaD_growstack",
    "luaF_newCclosure",
    "luaH_getn",
    "luaH_getstr",
    "luaH_new",
    "luaH_newkey",
    "luaH_resize",
    "luaS_newudata",
}

-- Why we need this
-- ----------------

-- Pallene needs to use low-level Lua internals which are not exported by lua.h. To work around this
-- limitation, we provide a corelib.h and a corelib.so that re-export those missing symbols.
--
-- In the past, what we did was compile a custom version of Lua which redefined LUAI_FUNC so that
-- all those internal functions became public. That required few lines of code, but introduced
-- several headaches in other areas. The biggest one is that it asked our users to install a custom
-- Lua, possible a custom Luarocks, etc. We also had trouble with the #include directives related to
-- the internal ".h" files. It required passing appropriate -I flags whenever we compiled generated
-- code. There was also the problem of where to install the headers.. That was a problem we never
-- solved. We required that the current working dir had to be the root of the reposirtory.
--
-- Our solution to the header file problem was to get rid of all #include directives. We use a code
-- generation step to inline all the headers.
--
-- As for the custom Lua, we have switched to an architecture that allows installing Pallene as a
-- regular Luarocks package, running on vanilla PUC-Lua. The pallene library and internal functions
-- are now packaged as a C extension module. The tricky bit is that we can't use "extern" functions
-- to export our low-level C functions, because Lua's require() loads the ".so" using the RTLD_LOCAL
-- flag. Our workaround is to put the library in a struct of function pointers and pass that around
-- in an userdata. Similarly to the inlined headers, this makes the generated C code a bit weirder
-- to read, but simplifies the life further down the road. For example, don't have to worry about
-- platform-specific dynamic linking behavior, or having to pass -L flags to the C compiler.

--
-- Helper Functions
--

local function write_box_comment(msg)
    local line = msg:gsub(".", "-")
    io.write("\n")
    io.write("/*-",line,"-*/\n")
    io.write("/* ",msg, " */\n")
    io.write("/*-",line,"-*/\n")
    io.write("\n")
end

local function shell_escape(str)
    return "'" .. string.gsub(str, "'", "'\\''") .. "'"
end

local function writeln(...)
    io.write(...)
    io.write('\n')
end

-- Temporarily redirect the output stream to the chosen file.
-- Record the file name, so we can show it after we are done with everything.
local output_files = {}
local function with_output(path, body)
    table.insert(output_files, path)
    io.output(path)
    body()
    io.close()
end

--
-- 1) Set up the input and output directories
--

-- Check if we are already in the right dir.
-- I don't want to add a lfs dependency only for chdir...
local ok = os.execute("test -f README.md")
if not ok then
    io.stderr:write("Please run this script from the root of the repository\n")
    os.exit(1)
end

local tarname = "lua-"..LUA_RELEASE_STR
local targz  = "./downloaded/"..tarname..".tar.gz"
local luadir = "./downloaded/"..tarname
local srcdir = luadir.."/src"

-- Include a ".c" or ".h" file, removing any "include" directives.
-- It is our responsibility to print the files in the right order
-- We also remove comments and blank lines, just to be pretty / easier to scroll.
local function include(filename)

    if filename ~= "ljumptab.h" then
        write_box_comment(filename)
    end

    -- To ensure that we do the right thing even if there are comments inside string literals or
    -- things like that, use the C preprocessor to remove the comments.
    -- See: https://stackoverflow.com/a/13062682
    --
    -- 1) Escape the preprocessor directives, disabling them
    -- 2) Run through the preprocessor, which will only remove comments & blank lines
    -- 3) Undo the escaping
    local strip_cmd = string.gsub([[
        cat @infile |
        sed 's/a/aA/g; s/__/aB/g; s/#/aC/g' |
        cpp -P |
        sed 's/aC/#/g; s/aB/__/g; s/aA/a/g'
    ]], '@%w+', {
        ["@infile"] = shell_escape(srcdir.."/"..filename)
    })

    local stripped = io.popen(strip_cmd)
    for line in stripped:lines() do
        local dep = line:match('^#include *"(.-)"')
        if dep then
            if dep == 'ljumptab' then
                include("ljumptab.h")
            end
        else
            writeln(line)
        end
    end
    stripped:close()
end

--
-- 2) Download Lua from upstream
--

local download_cmd =
    string.gsub([[
        mkdir -p downloaded || exit
        cd downloaded || exit

        if ! test -f @targz; then
            echo "DOWNLOADING LUA" >&2
            curl -R -O http://www.lua.org/ftp/@targz
        fi

        if ! test -d @dirname; then
            echo "UNPACKING LUA" >&2
            tar zxf @targz
        fi
    ]], '@%w+', {
        ["@dirname"] = shell_escape(tarname),
        ["@targz"]   = shell_escape(tarname..".tar.gz"),
    })

os.execute(download_cmd)

--
-- 3) Identify core Lua files
--

local lua_core_h = {} -- Sorted topologically (leaf deps first)
local lua_core_c = {} -- Sorted alphabetically
do

    local use_system = {
        ["luaconf"] = true,
        ["lua"]     = true,
        ["lualib"]  = true,
        ["lauxlib"] = true,
    }

    -- Gather list of '.c' files
    local is_core = {}
    local csearch = io.popen(
        "cd "..srcdir.." && grep -R --files-with-matches '#define LUA_CORE'")
    for line in csearch:lines() do
        local name = line:match("^(.-)%.c$")
        -- Skip over files that implement the public API
        -- because we will use the system version of that.
        if not (use_system[name] or name == "lapi") then
            table.insert(lua_core_c, line)
            is_core[name] = true
        end
    end
    csearch:close()
    table.sort(lua_core_c)

    -- Gather list of '.h' files
    local unsorted_h = {}
    local hsearch = io.popen("cd  "..srcdir.." && ls *.h")
    for line in hsearch:lines() do
        local name = line:match("^(.-)%.h$")
        -- ljumptab is not an interface file, and therefore
        -- should be handled specially.
        if not (use_system[name] or name == "ljumptab") then
            table.insert(unsorted_h, line)
        end
    end
    hsearch:close()

    -- Sort '.h' files
    local visited = {}
    local function visit(header)
        local name = header:match('^(.*)%.h$')
        if use_system[name] then return end
        if name == "ljumptab" then return end
        if visited[name] then return end

        visited[name] = true
        local path = srcdir..'/'..header
        local depsearch = io.popen([[grep '#include ".*"' ]]..path)
        for line in depsearch:lines() do
            local dep = line:match('#include "(.-)"')
            if dep ~= name then
                visit(dep)
            end
        end
        depsearch:close()

        table.insert(lua_core_h, header)
    end
    for _, header in ipairs(unsorted_h) do
        visit(header)
    end
end

--
-- 4) Generate _corelib_lua.h
--

with_output("pallene/_corelib_lua.h", function()

    writeln("/* This file was generated by ",arg[0], " */")
    writeln("/* Please see the copyright notice in the LICENSE file */")

    -- lprefix only has an effect if it is the very first thing
    include("lprefix.h")

    -- The following define enables the l_likely and l_unlikely macros
    writeln("#define LUA_CORE")

    -- The public Lua API will be provided by the system lualib, hence we should use system headers.
    -- In particular, it is very important that we refer to the same luaconf.h as the interpreter.
    write_box_comment("Public Lua headers")
    writeln("#include <luaconf.h>")
    writeln("#include <lua.h>")
    writeln("#include <lualib.h>")
    writeln("#include <lauxlib.h>")

    -- Check if the Lua version is the correct one
    writeln("#if LUA_VERSION_RELEASE_NUM != ", LUA_RELEASE_NUM)
    writeln('#error "Lua version must be exactly ', LUA_RELEASE_STR,'"')
    writeln("#endif")

    for _, name in ipairs(lua_core_h) do
        include(name)
    end
end)

--
-- 5) Generate _corelib_lua.c
--

with_output("pallene/_corelib_lua.c", function()
    for _, name in ipairs(lua_core_c) do
        include(name)
    end
end)

--
-- 6) Generate _corelib_struct.h
--


-- Find the declaration of a given function name
local function find_definition(name, fileglob)

    assert(string.match(name, '^[%w_]*$'))

    -- Some declarations span more than one line.
    -- Grep a couple of the following lines...
    local search_cmd = string.gsub([[ grep --no-filename -A 20 '^LUAI_FUNC.*@func *(' @fileglob ]],
    '@%w+', {
        ["@func"] = name,
        ["@fileglob"] = fileglob,
    })

    local searched = io.popen(search_cmd)
    local str = searched:read("*a")
    searched:close()

    -- ... and then clean up the output in Lua
    local a, b = str:find(name, 1, true)
    local s1 = str:sub(1, a-1)
    local s2 = str:sub(b+1)

    s1 = s1:gsub("^LUAI_FUNC *", "")
    s1 = s1:gsub(' *$', "")

    s2 = s2:match(".-(%b())")
    s2 = s2:gsub("\n *", " ")

    return string.format("%s (*%s)%s;", s1, name, s2)
end

with_output("pallene/_corelib_struct.h", function()

    write_box_comment("corelib interface")

    writeln("#define PALLENE_LIB_VERSION ", CORELIB_VERSION)
    writeln("struct PalleneLib {")
    writeln("    uint64_t version;");

    for _, name in ipairs(exported_fns) do

        local fileglob
        if     name:match("^pallene") then
            fileglob = "./pallene/corelib_exported.c"
        elseif name:match("^lua") then
            fileglob = srcdir.."/*.h"
        else
            error("impossible")
        end

        writeln("    ", find_definition(name, fileglob))
    end

    writeln("};");
end)


--
-- 7) Generated _pallenelib_struct.c
--

with_output("pallene/_corelib_struct.c", function()

    write_box_comment("corelib exporting")

    writeln("struct PalleneLib pallene_lib = {")
    writeln("    PALLENE_LIB_VERSION,")
    for i, name in ipairs(exported_fns) do
        local comma = (i == #exported_fns) and "" or ","
        writeln("    ", name, comma)
    end
    writeln("};")
end)

--
-- 8) Generate _corelib_unstruct.h
--

with_output("pallene/_corelib_unstruct.h", function()

    local width = 0
    for i, name in ipairs(exported_fns) do
        width = math.max(width, #name)
    end

    for i, name in ipairs(exported_fns) do
        local space = string.rep(' ', width - #name)
        writeln(string.format("#define %s%s (pallene_lib.%s)", name, space, name))
    end
end)

--
-- 9) Generate _corelib_h.lua
--

table.insert(output_files, "pallene/_corelib.h")
os.execute(table.concat({
    "cat",
        "pallene/_corelib_lua.h",
        "pallene/_corelib_struct.h",
        "pallene/_corelib_unstruct.h",
        "pallene/corelib_inline.c",
        ">", "pallene/_corelib.h",
}, " "))

with_output("pallene/_corelibh.lua", function()

    local f = io.open("pallene/_corelib.h")
    local contents = f:read("*a")
    f:close()

    local open  = "[=["
    local close = "]=]"

    -- Ensure our string won't be broken
    assert(not(string.find(contents, close, 1, true)))

    writeln("return ", open)
    writeln(contents)
    writeln(close)

end)

--
-- 10) Generate _corelib.c
--

table.insert(output_files, "pallene/_corelib.c")
os.execute(table.concat({
    "cat",
        "pallene/_corelib_lua.h",
        "pallene/_corelib_lua.c",
        "pallene/_corelib_struct.h",
        "pallene/corelib_exported.c",
        "pallene/_corelib_struct.c",
        "pallene/corelib_luaopen.c",
        ">", "pallene/_corelib.c",
}, " "))

--
-- 11) Package c
--

--
-- Done!
--

io.output(io.stdout)
writeln("Generated following files:")
for _, name in ipairs(output_files) do
    writeln(name)
end

