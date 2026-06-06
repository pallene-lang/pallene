local Parser = require "argparse"
getmetatable(Parser()).error = function(_, msg) error(msg) end

describe("tests related to :pparse()", function()
   it("returns true and result on success", function()
      local parser = Parser()
      parser:option "-s --server"
      local ok, args = parser:pparse{"--server", "foo"}
      assert.is_true(ok)
      assert.same({server = "foo"}, args)
   end)

   it("returns false and bare error message on failure", function()
      local parser = Parser()
      parser:argument "foo"
      local ok, errmsg = parser:pparse{}
      assert.is_false(ok)
      assert.equal("missing argument 'foo'", errmsg)
   end)

   it("rethrows errors from callbacks", function()
      local parser = Parser()
      parser:flag "--foo"
         :action(function() error("some error message") end)
      assert.error_matches(function() parser:pparse{"--foo"} end, "some error message")
   end)
end)
