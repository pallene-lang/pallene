local util = require "pallene.util"


describe("Pallene utils", function()

     it("returns error when a file doesn't exist", function()
        local filename = "does_not_exist.pln"
        local ok, err = util.get_file_contents(filename)
        assert.falsy(ok)
        assert.matches(filename, err)
     end)

     it("writes a file to disk", function()
        local filename = "a_file.pln"
        local ok = util.set_file_contents(filename, "return {}")
        assert.truthy(ok)
        os.remove(filename)
     end)

     it("can extract stdout from commands", function()
         local cmd = [[lua -e 'io.stdout:write("hello")']]
         local ok, err, stdout, stderr = util.outputs_of_execute(cmd)
         assert(ok, err)
         assert.equals("hello", stdout)
         assert.equals("",      stderr)
     end)

     it("can extract stderr from commands", function()
         local cmd = [[lua -e 'io.stderr:write("hello")']]
         local ok, err, stdout, stderr = util.outputs_of_execute(cmd)
         assert(ok, err)
         assert.equals("",      stdout)
         assert.equals("hello", stderr)
     end)
end)
