local Parser = require "argparse"
getmetatable(Parser()).error = function(_, msg) error(msg) end

describe("tests related to usage message generation", function()
   it("creates correct usage message for empty parser", function()
      local parser = Parser "foo"
         :add_help(false)
      assert.equal(parser:get_usage(), "Usage: foo")
   end)

   it("creates correct usage message for arguments", function()
      local parser = Parser "foo"
         :add_help(false)
      parser:argument "first"
      parser:argument "second-and-third"
         :args "2"
      parser:argument "maybe-fourth"
         :args "?"
      parser:argument "others"
         :args "*"

      assert.equal([[
Usage: foo <first> <second-and-third> <second-and-third>
       [<maybe-fourth>] [<others>] ...]], parser:get_usage()
      )
   end)

   it("creates correct usage message for options", function()
      local parser = Parser "foo"
         :add_help(false)
      parser:flag "-q" "--quiet"
      parser:option "--from"
         :count "1"
         :target "server"
      parser:option "--config"

      assert.equal(
         [=[Usage: foo [-q] --from <from> [--config <config>]]=],
         parser:get_usage()
      )
   end)

   it("creates correct usage message for options with variable argument count", function()
      local parser = Parser "foo"
         :add_help(false)
      parser:argument "files"
         :args "+"
      parser:flag "-q" "--quiet"
      parser:option "--globals"
         :args "*"

      assert.equal(
         [=[Usage: foo [-q] <files> [<files>] ... [--globals [<globals>] ...]]=],
         parser:get_usage()
      )
   end)

   it("creates correct usage message for arguments with default value", function()
      local parser = Parser "foo"
         :add_help(false)
      parser:argument "input"
         :default "a.in"
      parser:argument "pair"
         :args(2)
         :default "foo"
      parser:argument "pair2"
         :args(2)
         :default "bar"
         :defmode "arg"

      assert.equal(
         [=[Usage: foo [<input>] [<pair> <pair>] [<pair2>] [<pair2>]]=],
         parser:get_usage()
      )
   end)

   it("creates correct usage message for options with default value", function()
      local parser = Parser "foo"
         :add_help(false)
      parser:option "-f" "--from"
         :default "there"
      parser:option "-o" "--output"
         :default "a.out"
         :defmode "arg"

      assert.equal(
         [=[Usage: foo [-f <from>] [-o [<output>]]]=],
         parser:get_usage()
      )
   end)

   it("creates correct usage message for arguments with choices", function()
      local parser = Parser "foo"
         :add_help(false)
      parser:argument "move"
         :choices {"rock", "paper", "scissors"}

      assert.equal(
         [=[Usage: foo {rock,paper,scissors}]=],
         parser:get_usage()
      )
   end)

   it("creates correct usage message for options with argument choices", function()
      local parser = Parser "foo"
         :add_help(false)
      parser:option "--format"
         :choices {"short", "medium", "full"}

      assert.equal(
         [=[Usage: foo [--format {short,medium,full}]]=],
         parser:get_usage()
      )
   end)

   it("creates correct usage message for commands", function()
      local parser = Parser "foo"
         :add_help(false)
      parser:flag "-q" "--quiet"
      local run = parser:command "run"
      run:option "--where"

      assert.equal(
         [=[Usage: foo [-q] <command> ...]=],
         parser:get_usage()
      )
   end)

   it("creates correct usage message for subcommands", function()
      local parser = Parser "foo"
         :add_help(false)
      parser:flag "-q" "--quiet"
      local run = parser:command "run"
         :add_help(false)
      run:option "--where"

      assert.equal(
         [=[Usage: foo run [--where <where>]]=],
         run:get_usage()
      )
   end)

   it("omits usage for hidden arguments and options", function()
      local parser = Parser "foo"
         :add_help(false)
      parser:flag "-d" "--deprecated"
         :hidden(true)
      parser:flag "-n" "--not-deprecated"
      parser:argument "normal"
      parser:argument "deprecated"
         :args "?"
         :hidden(true)

      assert.equal(
         [=[Usage: foo [-n] <normal>]=],
         parser:get_usage()
      )
   end)

   it("omits usage for mutexes if all elements are hidden", function()
      local parser = Parser "foo"
         :add_help(false)
      parser:mutex(
         parser:flag "--misfeature"
            :hidden(true),
         parser:flag "--no-misfeature"
            :action "store_false"
            :target "misfeature"
            :hidden(true)
      )
      parser:flag "--feature"

      assert.equal(
         [=[Usage: foo [--feature]]=],
         parser:get_usage()
      )
   end)

   it("usage messages for commands are correct after several invocations", function()
      local parser = Parser "foo"
         :add_help(false)
      parser:flag "-q" "--quiet"
      local run = parser:command "run"
         :add_help(false)
      run:option "--where"

      parser:parse{"run"}
      parser:parse{"run"}

      assert.equal(
         [=[Usage: foo run [--where <where>]]=],
         run:get_usage()
      )
   end)

   describe("usage generation can be customized", function()
      it("uses message provided by user", function()
         local parser = Parser "foo"
            :usage "Usage: obvious"
            :add_help(false)
         parser:flag "-q" "--quiet"

         assert.equal(
            [=[Usage: obvious]=],
            parser:get_usage()
         )
      end)

      it("uses argnames provided by user", function()
         local parser = Parser "foo"
            :add_help(false)
         parser:argument "inputs"
            :args "1-2"
            :argname "<input>"

         assert.equal(
            [=[Usage: foo <input> [<input>]]=],
            parser:get_usage()
         )
      end)

      it("uses array of argnames provided by user", function()
         local parser = Parser "foo"
            :add_help(false)
         parser:option "--pair"
            :args(2)
            :count "*"
            :argname{"<key>", "<value>"}

         assert.equal(
            [=[Usage: foo [--pair <key> <value>]]=],
            parser:get_usage()
         )
      end)
   end)

   it("creates correct usage message for mutexes", function()
      local parser = Parser "foo"
         :add_help(false)
      parser:mutex(
         parser:flag "-q" "--quiet",
         parser:flag "-v" "--verbose",
         parser:flag "-i" "--interactive"
      )
      parser:mutex(
         parser:flag "-l" "--local",
         parser:option "-f" "--from"
      )
      parser:option "--yet-another-option"

      assert.equal([=[
Usage: foo ([-q] | [-v] | [-i]) ([-l] | [-f <from>])
       [--yet-another-option <yet_another_option>]]=], parser:get_usage()
      )
   end)

   it("creates correct usage message for mutexes with arguments", function()
      local parser = Parser "foo"
         :add_help(false)

      parser:argument "first"
      parser:mutex(
         parser:flag "-q" "--quiet",
         parser:flag "-v" "--verbose",
         parser:argument "second":args "?"
      )
      parser:argument "third"
      parser:mutex(
         parser:flag "-l" "--local",
         parser:option "-f" "--from"
      )
      parser:option "--yet-another-option"

      assert.equal([=[
Usage: foo ([-l] | [-f <from>])
       [--yet-another-option <yet_another_option>] <first>
       ([-q] | [-v] | [<second>]) <third>]=], parser:get_usage()
      )
   end)

   it("puts vararg option and mutex usages after positional arguments", function()
      local parser = Parser "foo"
         :add_help(false)
      parser:argument("argument")
      parser:mutex(
         parser:flag "-q" "--quiet",
         parser:flag "-v" "--verbose",
         parser:flag "-i" "--interactive"
      )
      parser:mutex(
         parser:flag "-a -all",
         parser:option "-i --ignore":args("*")
      )
      parser:option "--yet-another-option"
      parser:option "--vararg-option":args("1-2")

      assert.equal([=[
Usage: foo ([-q] | [-v] | [-i])
       [--yet-another-option <yet_another_option>] <argument>
       ([-a] | [-i [<ignore>] ...])
       [--vararg-option <vararg_option> [<vararg_option>]]]=], parser:get_usage()
      )
   end)

   it("doesn't repeat usage of elements within several mutexes", function()
      local parser = Parser "foo"
         :add_help(false)

      parser:argument("arg1")
      local arg2 = parser:argument("arg2"):args "?"
      parser:argument("arg3"):args "?"
      local arg4 = parser:argument("arg4"):args "?"

      local opt1 = parser:option("--opt1")
      local opt2 = parser:option("--opt2")
      local opt3 = parser:option("--opt3")
      local opt4 = parser:option("--opt4")
      local opt5 = parser:option("--opt5")
      local opt6 = parser:option("--opt6")
      parser:option("--opt7")

      parser:mutex(arg2, opt1, opt2)
      parser:mutex(arg4, opt2, opt3, opt4)
      parser:mutex(opt1, opt3, opt5)
      parser:mutex(opt1, opt3, opt6)

      assert.equal([=[
Usage: foo ([--opt1 <opt1>] | [--opt3 <opt3>] | [--opt5 <opt5>])
       [--opt6 <opt6>] [--opt7 <opt7>] <arg1>
       ([<arg2>] | [--opt2 <opt2>]) [<arg3>]
       ([<arg4>] | [--opt4 <opt4>])]=], parser:get_usage()
      )
   end)

   it("allows configuring usage margin using usage_margin property", function()
      local parser = Parser "foo"
         :usage_margin(2)

      parser:argument "long_argument_name"
      parser:argument "very_long_words"

      parser:option "--set-important-property"
      parser:option "--include"
         :args "*"

      assert.equals([=[
Usage: foo [-h] [--set-important-property <set_important_property>]
  <long_argument_name> <very_long_words> [--include [<include>] ...]]=], parser:get_usage())
   end)

   it("allows configuring max usage width using usage_max_width property", function()
      local parser = Parser "foo"
         :usage_max_width(50)

      parser:argument "long_argument_name"
      parser:argument "very_long_words"

      parser:option "--set-important-property"
      parser:option "--include"
         :args "*"

      assert.equals([=[
Usage: foo [-h]
       [--set-important-property <set_important_property>]
       <long_argument_name> <very_long_words>
       [--include [<include>] ...]]=], parser:get_usage())
   end)
end)
