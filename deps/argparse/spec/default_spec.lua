local Parser = require "argparse"
getmetatable(Parser()).error = function(_, msg) error(msg) end

describe("tests related to default values", function()
   describe("default values for arguments", function()
      it("handles default argument correctly", function()
         local parser = Parser()
         parser:argument "foo"
            :default "bar"
         local args = parser:parse{}
         assert.same({foo = "bar"}, args)
         args = parser:parse{"baz"}
         assert.same({foo = "baz"}, args)
      end)

      it("handles default argument for multi-argument correctly", function()
         local parser = Parser()
         parser:argument "foo" {
            args = 3,
            default = "bar",
            defmode = "arg"
         }
         local args = parser:parse{"baz"}
         assert.same({foo = {"baz", "bar", "bar"}}, args)
      end)

      it("handles default value for multi-argument correctly", function()
         local parser = Parser()
         parser:argument "foo" {
            args = 3,
            default = "bar"
         }
         local args = parser:parse{}
         assert.same({foo = {"bar", "bar", "bar"}}, args)
      end)

      it("does not use default values if not needed", function()
         local parser = Parser()
         parser:argument "foo" {
            args = "1-2",
            default = "bar"
         }
         local args = parser:parse({"baz"})
         assert.same({foo = {"baz"}}, args)
      end)
   end)

   describe("default values for options", function()
      it("handles option with default value correctly", function()
         local parser = Parser()
         parser:option "-o" "--output"
            :default "a.out"
            :defmode "unused"
         local args = parser:parse{}
         assert.same({output = "a.out"}, args)
         args = parser:parse{"--output", "foo.txt"}
         assert.same({output = "foo.txt"}, args)
         assert.has_error(function() parser:parse{"-o"} end, "option '-o' requires an argument")
      end)

      it("handles option with default value for multi-argument option correctly", function()
         local parser = Parser()
         parser:option("-s --several", "Two or three things", "foo", nil, "2-3")
         local args = parser:parse{}
         assert.same({several = {"foo", "foo"}}, args)
      end)

      it("handles option with default value and argument", function()
         local parser = Parser()
         parser:option "-o" "--output" {
            default = "a.out",
            defmode = "arg+count"
         }
         local args = parser:parse{}
         assert.same({output = "a.out"}, args)
         args = parser:parse{"-o"}
         assert.same({output = "a.out"}, args)
         args = parser:parse{"-o", "value"}
         assert.same({output = "value"}, args)
      end)

      it("handles option with default argument correctly", function()
         local parser = Parser()
         parser:option "-p" "--protected"
            :target "password"
            :default "password"
            :defmode "arg"
         local args = parser:parse{"-p"}
         assert.same({password = "password"}, args)
      end)

      it("doesn't use default argument if option is not invoked", function()
         local parser = Parser()
         parser:option "-f" "--foo" {
            default = "bar",
            defmode = "arg"
         }
         local args = parser:parse{}
         assert.same({}, args)
      end)

      it("handles default multi-argument correctly", function()
         local parser = Parser()
         parser:option "-f" "--foo" {
            args = 3,
            default = "bar",
            defmode = "arg"
         }
         local args = parser:parse({"--foo=baz"})
         assert.same({foo = {"baz", "bar", "bar"}}, args)
      end)

      it("does not use default values if not needed", function()
         local parser = Parser()
          parser:option "-f" "--foo" {
            args = "1-2",
            default = "bar",
            defmode = "arg"
         }
         local args = parser:parse({"-f", "baz"})
         assert.same({foo = {"baz"}}, args)
      end)

      it("handles multi-count options with default value correctly", function()
         local parser = Parser()
          parser:option "-f" "--foo" {
            count = "*",
            default = "bar",
            defmode = "arg + count"
         }
         local args = parser:parse({"-f", "--foo=baz", "--foo"})
         assert.same({foo = {"bar", "baz", "bar"}}, args)
      end)

      it("completes missing invocations for multi-count options with default argument", function()
         local parser = Parser()
          parser:option "-f" "--foo" {
            count = "2",
            default = "bar",
            defmode = "arg"
         }
         local args = parser:parse({"-ffff"})
         assert.same({foo = {"fff", "bar"}}, args)
      end)
   end)
end)
