local Parser = require "argparse"
getmetatable(Parser()).error = function(_, msg) error(msg) end

describe("tests related to mutexes", function()
   it("handles mutex correctly", function()
      local parser = Parser()
      parser:mutex(
         parser:flag "-q" "--quiet"
            :description "Supress logging. ",
         parser:flag "-v" "--verbose"
            :description "Print additional debug information. "
      )

      local args = parser:parse{"-q"}
      assert.same({quiet = true}, args)
      args = parser:parse{"-v"}
      assert.same({verbose = true}, args)
      args = parser:parse{}
      assert.same({}, args)
   end)

   it("handles mutex with an argument", function()
      local parser = Parser()
      parser:mutex(
         parser:flag "-q" "--quiet"
            :description "Supress output.",
         parser:argument "log"
            :args "?"
            :description "Log file"
      )

      local args = parser:parse{"-q"}
      assert.same({quiet = true}, args)
      args = parser:parse{"log.txt"}
      assert.same({log = "log.txt"}, args)
      args = parser:parse{}
      assert.same({}, args)
   end)

   it("handles mutex with default value", function()
      local parser = Parser()
      parser:mutex(
         parser:flag "-q" "--quiet",
         parser:option "-o" "--output"
            :default "a.out"
      )

      local args = parser:parse{"-q"}
      assert.same({quiet = true, output = "a.out"}, args)
   end)

   it("raises an error if mutex is broken", function()
      local parser = Parser()
      parser:mutex(
         parser:flag "-q" "--quiet"
            :description "Supress logging. ",
         parser:flag "-v" "--verbose"
            :description "Print additional debug information. "
      )

      assert.has_error(function()
         parser:parse{"-qv"}
      end, "option '-v' can not be used together with option '-q'")
      assert.has_error(function()
         parser:parse{"-v", "--quiet"}
      end, "option '--quiet' can not be used together with option '-v'")
   end)

   it("raises an error if mutex with an argument is broken", function()
      local parser = Parser()
      parser:mutex(
         parser:flag "-q" "--quiet"
            :description "Supress output.",
         parser:argument "log"
            :args "?"
            :description "Log file"
      )

      assert.has_error(function()
         parser:parse{"-q", "log.txt"}
      end, "argument 'log' can not be used together with option '-q'")
      assert.has_error(function()
         parser:parse{"log.txt", "--quiet"}
      end, "option '--quiet' can not be used together with argument 'log'")
   end)

   it("handles multiple mutexes", function()
      local parser = Parser()
      parser:mutex(
         parser:flag "-q" "--quiet",
         parser:flag "-v" "--verbose"
      )
      parser:mutex(
         parser:flag "-l" "--local",
         parser:option "-f" "--from"
      )

      local args = parser:parse{"-qq", "-fTHERE"}
      assert.same({quiet = true, from = "THERE"}, args)
      args = parser:parse{"-vl"}
      assert.same({verbose = true, ["local"] = true}, args)
   end)

   it("handles mutexes in commands", function()
      local parser = Parser()
      parser:mutex(
         parser:flag "-q" "--quiet",
         parser:flag "-v" "--verbose"
      )
      local install = parser:command "install"
      install:mutex(
         install:flag "-l" "--local",
         install:option "-f" "--from"
      )

      local args = parser:parse{"install", "-l"}
      assert.same({install = true, ["local"] = true}, args)
      assert.has_error(function()
         parser:parse{"install", "-qlv"}
      end, "option '-v' can not be used together with option '-q'")
   end)
end)
