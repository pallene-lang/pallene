local Parser = require "argparse"
getmetatable(Parser()).error = function(_, msg) error(msg) end

describe("tests related to converters", function()
   it("converts arguments", function()
      local parser = Parser()
      parser:argument "numbers" {
         convert = tonumber,
         args = "+"
      }

      local args = parser:parse{"1", "2", "500"}
      assert.same({numbers = {1, 2, 500}}, args)
   end)

   it("accepts an array of converters", function()
      local function tocoords(str)
         local x, y = str:match("^([^,]*),([^,]*)$")
         x = tonumber(x)
         y = tonumber(y)
         return x and y and {x, y}
      end

      local parser = Parser()
      parser:option "-c --circle" {
         convert = {tonumber, tocoords},
         args = 2
      }

      local args = parser:parse{"-c", "123", "456,567"}
      assert.same({circle = {123, {456, 567}}}, args)
   end)

   it("converts arguments using mapping", function()
      local choice = {
         foo = 1,
         bar = 2
      }

      local parser = Parser()
      parser:argument "choice" {
         convert = choice,
         args = "+"
      }

      local args = parser:parse{"foo", "bar"}
      assert.same({choice = {1, 2}}, args)
   end)

   it("accepts false", function()
      local function toboolean(x)
         if x == "true" then
            return true
         elseif x == "false" then
            return false
         end
      end

      local parser = Parser()
      parser:argument "booleans" {
         convert = toboolean,
         args = "+"
      }

      local args = parser:parse{"true", "false"}
      assert.same({booleans = {true, false}}, args)
   end)

   it("raises an error when it can't convert", function()
      local parser = Parser()
      parser:argument "numbers" {
         convert = tonumber,
         args = "+"
      }

      assert.has_error(function() parser:parse{"foo", "bar", "baz"} end, "malformed argument 'foo'")
   end)

   it("second return value is used as error message", function()
      local parser = Parser()
      parser:argument "numbers" {
         convert = function(x) return tonumber(x), x .. " is not a number" end
      }

      assert.has_error(function() parser:parse{"foo"} end, "foo is not a number")
   end)
end)
