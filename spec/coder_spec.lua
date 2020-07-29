local util = require "pallene.util"
local execution_tests = require "spec.execution_tests"

local function compile(pallene_code)
    setup(function()
        assert(util.set_file_contents("__test__.pln", pallene_code))
        local ok, _, _, errmsg = util.outputs_of_execute("./pallenec __test__.pln")
        if not ok then
            error(errmsg)
        end
    end)
+
    it("does not crash the #prettyprinter", function()
        local ok, _, _, errmsg = util.outputs_of_execute("./pallenec --print-ir __test__.pln")
        if not ok then error(errmsg) end
    end)
end

local function cleanup()
    os.remove("__test__.pln")
    os.remove("__test__.so")
    os.remove("__test__script__.lua")
    os.remove("__test__output__.txt")
end

describe("#c_backend /", function ()
    teardown(cleanup)
    execution_tests.run(compile, 'c', describe, it, assert)
end)
