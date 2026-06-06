local Parser = require "argparse"
getmetatable(Parser()).error = function(_, msg) error(msg) end

describe("tests related to positional arguments", function()
   describe("passing correct arguments", function()
      it("handles empty parser correctly", function()
         local parser = Parser()
         local args = parser:parse({})
         assert.same({}, args)
      end)

      it("handles one argument correctly", function()
         local parser = Parser()
         parser:argument "foo"
         local args = parser:parse({"bar"})
         assert.same({foo = "bar"}, args)
      end)

      it("handles optional argument correctly", function()
         local parser = Parser()
         parser:argument "foo"
            :args "?"
         local args = parser:parse({"bar"})
         assert.same({foo = "bar"}, args)
      end)

      it("handles several arguments correctly", function()
         local parser = Parser()
         parser:argument "foo1"
         parser:argument "foo2"
         local args = parser:parse({"bar", "baz"})
         assert.same({foo1 = "bar", foo2 = "baz"}, args)
      end)

      it("handles multi-argument correctly", function()
         local parser = Parser()
         parser:argument "foo" {
            args = "*"
         }
         local args = parser:parse({"bar", "baz", "qu"})
         assert.same({foo = {"bar", "baz", "qu"}}, args)
      end)

      it("handles restrained multi-argument correctly", function()
         local parser = Parser()
         parser:argument "foo" {
            args = "2-4"
         }
         local args = parser:parse({"bar", "baz"})
         assert.same({foo = {"bar", "baz"}}, args)
      end)

      it("handles several multi-arguments correctly", function()
         local parser = Parser()
         parser:argument "foo1" {
            args = "1-2"
         }
         parser:argument "foo2" {
            args = "*"
         }
         local args = parser:parse({"bar"})
         assert.same({foo1 = {"bar"}, foo2 = {}}, args)
         args = parser:parse({"bar", "baz", "qu"})
         assert.same({foo1 = {"bar", "baz"}, foo2 = {"qu"}}, args)
      end)

      it("handles hyphen correctly", function()
         local parser = Parser()
         parser:argument "foo"
         local args = parser:parse({"-"})
         assert.same({foo = "-"}, args)
      end)

      it("handles double hyphen correctly", function()
         local parser = Parser()
         parser:argument "foo"
         local args = parser:parse({"--", "-q"})
         assert.same({foo = "-q"}, args)
      end)
   end)

   describe("passing incorrect arguments", function()
      it("handles extra arguments with empty parser correctly", function()
         local parser = Parser()

         assert.has_error(function() parser:parse{"foo"} end, "too many arguments")
      end)

      it("handles extra arguments with one argument correctly", function()
         local parser = Parser()
         parser:argument "foo"

         assert.has_error(function() parser:parse{"bar", "baz"} end, "too many arguments")
      end)

      it("handles too few arguments with one argument correctly", function()
         local parser = Parser()
         parser:argument "foo"

         assert.has_error(function() parser:parse{} end, "missing argument 'foo'")
      end)

      it("handles extra arguments with several arguments correctly", function()
         local parser = Parser()
         parser:argument "foo1"
         parser:argument "foo2"

         assert.has_error(function() parser:parse{"bar", "baz", "qu"} end, "too many arguments")
      end)

      it("handles too few arguments with several arguments correctly", function()
         local parser = Parser()
         parser:argument "foo1"
         parser:argument "foo2"

         assert.has_error(function() parser:parse{"bar"} end, "missing argument 'foo2'")
      end)

      it("handles too few arguments with multi-argument correctly", function()
         local parser = Parser()
         parser:argument "foo" {
            args = "+"
         }
         assert.has_error(function() parser:parse{} end, "missing argument 'foo'")
      end)

      it("handles too many arguments with multi-argument correctly", function()
         local parser = Parser()
         parser:argument "foo" {
            args = "2-4"
         }
         assert.has_error(function() parser:parse{"foo", "bar", "baz", "qu", "quu"} end, "too many arguments")
      end)

      it("handles too few arguments with multi-argument correctly", function()
         local parser = Parser()
         parser:argument "foo" {
            args = "2-4"
         }
         assert.has_error(function() parser:parse{"foo"} end, "argument 'foo' requires at least 2 arguments")
      end)

      it("handles too many arguments with several multi-arguments correctly", function()
         local parser = Parser()
         parser:argument "foo1" {
            args = "1-2"
         }
         parser:argument "foo2" {
            args = "0-1"
         }
         assert.has_error(function() parser:parse{"foo", "bar", "baz", "qu"} end, "too many arguments")
      end)

      it("handles too few arguments with several multi-arguments correctly", function()
         local parser = Parser()
         parser:argument "foo1" {
            args = "1-2"
         }
         parser:argument "foo2" {
            args = "*"
         }
         assert.has_error(function() parser:parse{} end, "missing argument 'foo1'")
      end)

      it("handles invalid argument choices correctly", function()
         local parse = Parser()
         parse:argument "foo" {
            choices = {"bar", "baz", "qu"}
         }
         assert.has_error(function()
            parse:parse{"foo", "quu"}
         end, "argument 'foo' must be one of 'bar', 'baz', 'qu'")
      end)
   end)
end)
