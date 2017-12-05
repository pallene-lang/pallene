local parser = require  "titan-compiler.parser"
local util = require "titan-compiler.util"
local checker = require "titan-compiler.checker"
local coder = require "titan-compiler.coder"
local pretty = require "titan-compiler.pretty"
local types = require "titan-compiler.types"

local lfs = require "lfs"

local driver = {}

driver.imported = {}

driver.TITAN_BIN_PATH = os.getenv("TITAN_PATH_0_5") or os.getenv("TITAN_PATH") or ".;/usr/local/lib/titan/0.5"
driver.TITAN_SOURCE_PATH = "."

local CIRCULAR_MARK = {}

local function mod2so(modf)
    return modf:gsub("[.]titan$", "") .. ".so"
end

local function findmodule(paths, modname, extension)
    local modf = modname:gsub("[.]", "/") .. extension
    for path in paths:gmatch("[^;]+") do
        local filename = path .. "/" .. modf
        local mtime = lfs.attributes(filename, "modification")
        if mtime then return mtime, filename end
    end
    return nil
end

function driver.defaultloader(modname)
    if driver.imported[modname] == CIRCULAR_MARK then
        driver.imported[modname] = nil
        return false, "circular reference to module"
    end
    if driver.imported[modname] then
        local mod = driver.imported[modname]
        return true, mod.type
    end
    local mtime_bin, binf = findmodule(driver.TITAN_BIN_PATH, modname, ".so")
    local mtime_src, srcf = findmodule(driver.TITAN_SOURCE_PATH, modname, ".titan")
    if mtime_bin and (not mtime_src or mtime_bin >= mtime_src) then
        local typesf, err = package.loadlib(binf, modname:gsub("[%-.]", "_") .. "_types")
        if not typesf then return false, err end
        local ok, types_or_err = pcall(typesf)
        if not ok then return false, types_or_err end
        local modtf, err = load("return " .. types_or_err, modname, "t", types)
        if not modtf then return false, err end
        local ok, modt_or_err = pcall(modtf)
        if not ok then return false, modt_or_err end
        driver.imported[modname] = { type = modt_or_err, compiled = true }
        return true, modt_or_err, {}
    end
    if not mtime_src then return false, "module '" .. modname .. "' not found" end
    local input, err = util.get_file_contents(srcf)
    if not input then return false, err end
    local ast, err = parser.parse(input)
    if not ast then return false, parser.error_to_string(err, srcf) end
    driver.imported[modname] = CIRCULAR_MARK
    local modt, errors = checker.check(modname, ast, input, srcf, driver.defaultloader)
    driver.imported[modname] = { ast = ast, type = modt, filename = srcf }
    return true, modt, errors
end

function driver.tableloader(modtable, imported)
    local function loader(modname)
        if imported[modname] == CIRCULAR_MARK then
            imported[modname] = nil
            return false, "circular reference to module"
        end
        if imported[modname] then
            local mod = imported[modname]
            return true, mod.type
        end
        local modf = "./" .. modname .. ".titan"
        local input = modtable[modname]
        local ast, err = parser.parse(modtable[modname])
        if not ast then return false, parser.error_to_string(err, modf) end
        imported[modname] = CIRCULAR_MARK
        local modt, errors = checker.check(modname, ast, input, modf, loader)
        imported[modname] = { ast = ast, type = modt, filename = modf }
        return true, modt, errors
    end
    return loader
end

function driver.compile_module(CC, CFLAGS, modname, mod)
    if mod.compiled then return true end
    local code = coder.generate(modname, mod.ast)
    code = pretty.reindent_c(code)
    local filename = mod.filename:gsub("[.]titan$", "") .. ".c"
    local soname = mod.filename:gsub("[.]titan$", "") .. ".so"
    os.remove(filename)
    os.remove(soname)
    local ok, err = util.set_file_contents(filename, code)
    if not ok then return nil, err end
    local cc_cmd = string.format([[
        %s %s -shared %s -o %s
        ]], CC, CFLAGS, filename, soname)
    --print(cc_cmd)
    local ok, err = os.execute(cc_cmd)
    if not ok then return nil, err end
    mod.compiled = true
    return true
end


return driver

