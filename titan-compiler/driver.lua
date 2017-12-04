local parser = require  "titan-compiler.parser"
local util = require "titan-compiler.util"
local checker = require "titan-compiler.checker"
local coder = require "titan-compiler.coder"
local pretty = require "titan-compiler.pretty"
local types = require "titan-compiler.types"

local driver = {}

driver.imported = {}

local CIRCULAR_MARK = {}

local function mod2so(modf)
    return modf:gsub("[.]titan$", "") .. ".so"
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
    local SOPATH = "./?.so;/usr/local/lib/titan/0.5/?.so"
    local modf, err = package.searchpath(modname, SOPATH)
    if modf then
        local typesf, err = package.loadlib(modf, modname:gsub("[%-.]", "_") .. "_types")
        if typesf then
            local ok, types_or_err = pcall(typesf)
            if not ok then return false, types_or_err end
            local modtf, err = load("return " .. types_or_err, modname, "t", types)
            if not modtf then return false, err end
            local ok, modt_or_err = pcall(modtf)
            if not ok then return false, modt_or_err end
            driver.imported[modname] = { type = modt_or_err, compiled = true }
            return true, modt_or_err, {}
        end
    end
    local SEARCHPATH = "./?.titan" -- TODO: make this a configuration option for titanc
    local modf, err = package.searchpath(modname, SEARCHPATH)
    if not modf then return false, err end
    local input, err = util.get_file_contents(modf)
    if not input then return false, err end
    local ast, err = parser.parse(input)
    if not ast then return false, parser.error_to_string(err, modf) end
    driver.imported[modname] = CIRCULAR_MARK
    local modt, errors = checker.check(modname, ast, input, modf, driver.defaultloader)
    driver.imported[modname] = { ast = ast, type = modt, filename = modf }
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

