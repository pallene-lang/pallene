local util = require "pallene.util"


describe("Titan utils", function()

     it("returns error when a file doesn't exist", function()

        local filename = "does_not_exist.titan"
        local ok, err = util.get_file_contents(filename)
        assert.falsy(ok)
        assert.matches(filename, err)

     end)

     it("writes a file to disk", function()

        local filename = "a_file.titan"
        local ok = util.set_file_contents(filename, "return {}")
        assert.truthy(ok)
        os.remove(filename)

     end)
end)
