local Parser = require "argparse"

describe("invalid property detection", function()
   it("detects properties with invalid type", function()
      assert.has_error(function()
         Parser():name(12345)
      end, "bad property 'name' (string expected, got number)")

      assert.has_error(function()
         Parser():option "--foo":convert(true)
      end, "bad property 'convert' (function or table expected, got boolean)")
   end)

   it("detects invalid count and args properties", function()
      assert.has_error(function()
         Parser():option "--foo":count(false)
      end, "bad property 'count' (number or string expected, got boolean)")

      assert.has_error(function()
         Parser():option "--foo":args({})
      end, "bad property 'args' (number or string expected, got table)")

      assert.has_error(function()
         Parser():option "--foo":count("foobar")
      end, "bad property 'count'")

      assert.has_error(function()
         Parser():option "--foo":args("123-")
      end, "bad property 'args'")
   end)

   it("detects unknown named actions", function()
      assert.has_error(function()
         Parser():option "--foo":action(false)
      end, "bad property 'action' (function or string expected, got boolean)")

      assert.has_error(function()
         Parser():option "--foo":action("catcat")
      end, "unknown action 'catcat'")
   end)
end)
