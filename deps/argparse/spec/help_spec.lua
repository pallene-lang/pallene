local Parser = require "argparse"
getmetatable(Parser()).error = function(_, msg) error(msg) end

describe("tests related to help message generation", function()
   it("creates correct help message for empty parser", function()
      local parser = Parser "foo"
      assert.equal([[
Usage: foo [-h]

Options:
   -h, --help            Show this help message and exit.]], parser:get_help())
   end)

   it("uses custom help option ", function()
      local parser = Parser "foo"
         :add_help "/?"
      assert.equal([[
Usage: foo [/?]

Options:
   /?                    Show this help message and exit.]], parser:get_help())
   end)

   it("uses description and epilog", function()
      local parser = Parser("foo", "A description.", "An epilog.")

      assert.equal([[
Usage: foo [-h]

A description.

Options:
   -h, --help            Show this help message and exit.

An epilog.]], parser:get_help())
   end)

   it("creates correct help message for arguments", function()
      local parser = Parser "foo"
      parser:argument "first"
      parser:argument "second-and-third"
         :args "2"
      parser:argument "maybe-fourth"
         :args "?"
      parser:argument("others", "Optional.")
         :args "*"

      assert.equal([[
Usage: foo [-h] <first> <second-and-third> <second-and-third>
       [<maybe-fourth>] [<others>] ...

Arguments:
   first
   second-and-third
   maybe-fourth
   others                Optional.

Options:
   -h, --help            Show this help message and exit.]], parser:get_help())
   end)

   it("creates correct help message for options", function()
      local parser = Parser "foo"
      parser:flag "-q" "--quiet"
      parser:option "--from"
         :count "1"
         :target "server"
      parser:option "--config"

      assert.equal([[
Usage: foo [-h] [-q] --from <from> [--config <config>]

Options:
   -h, --help            Show this help message and exit.
   -q, --quiet
   --from <from>
   --config <config>]], parser:get_help())
   end)

   it("creates correct help message for arguments with choices", function()
      local parser = Parser "foo"
      parser:argument "move"
         :choices {"rock", "paper", "scissors"}

      assert.equal([[
Usage: foo [-h] {rock,paper,scissors}

Arguments:
   {rock,paper,scissors}

Options:
   -h, --help            Show this help message and exit.]], parser:get_help())
   end)

   it("creates correct help message for options with argument choices", function()
      local parser = Parser "foo"
      parser:option "--format"
         :choices {"short", "medium", "full"}

      assert.equal([[
Usage: foo [-h] [--format {short,medium,full}]

Options:
   -h, --help            Show this help message and exit.
   --format {short,medium,full}]], parser:get_help())
   end)

   it("adds margin for multiline descriptions", function()
      local parser = Parser "foo"
      parser:flag "-v"
         :count "0-2"
         :target "verbosity"
         :description [[
Sets verbosity level.
-v: Report all warnings.
-vv: Report all debugging information.]]

      assert.equal([[
Usage: foo [-h] [-v]

Options:
   -h, --help            Show this help message and exit.
   -v                    Sets verbosity level.
                         -v: Report all warnings.
                         -vv: Report all debugging information.]], parser:get_help())
   end)

   it("puts different aliases on different lines if there are arguments", function()
      local parser = Parser "foo"

      parser:option "-o --output"

      assert.equal([[
Usage: foo [-h] [-o <output>]

Options:
   -h, --help            Show this help message and exit.
         -o <output>,
   --output <output>]], parser:get_help())
   end)

   it("handles description with more lines than usage", function()
      local parser = Parser "foo"

      parser:option "-o --output"
         :description [[
Sets output file.
If missing, 'a.out' is used by default.
If '-' is passed, output to stdount.
]]

      assert.equal([[
Usage: foo [-h] [-o <output>]

Options:
   -h, --help            Show this help message and exit.
         -o <output>,    Sets output file.
   --output <output>     If missing, 'a.out' is used by default.
                         If '-' is passed, output to stdount.]], parser:get_help())
   end)

   it("handles description with less lines than usage", function()
      local parser = Parser "foo"

      parser:option "-o --output"
         :description "Sets output file."

      assert.equal([[
Usage: foo [-h] [-o <output>]

Options:
   -h, --help            Show this help message and exit.
         -o <output>,    Sets output file.
   --output <output>]], parser:get_help())
   end)

   it("handles very long argument lists", function()
      local parser = Parser "foo"

      parser:option "-t --at-least-three"
         :args("3+")
         :argname {"<foo>", "<bar>", "<baz>"}
         :description "Sometimes argument lists are really long."

      assert.equal([[
Usage: foo [-h] [-t <foo> <bar> <baz> ...]

Options:
   -h, --help            Show this help message and exit.
                 -t <foo> <bar> <baz> ...,
   --at-least-three <foo> <bar> <baz> ...
                         Sometimes argument lists are really long.]], parser:get_help())
   end)

   it("shows default values", function()
      local parser = Parser "foo"
      parser:option "-o"
         :default "a.out"
      parser:option "-p"
         :default "8080"
         :description "Port."

      assert.equal([[
Usage: foo [-h] [-o <o>] [-p <p>]

Options:
   -h, --help            Show this help message and exit.
   -o <o>                default: a.out
   -p <p>                Port. (default: 8080)]], parser:get_help())
   end)

   it("does not show default value when show_default == false", function()
      local parser = Parser "foo"
      parser:option "-o"
         :default "a.out"
         :show_default(false)
      parser:option "-p"
         :default "8080"
         :show_default(false)
         :description "Port."

      assert.equal([[
Usage: foo [-h] [-o <o>] [-p <p>]

Options:
   -h, --help            Show this help message and exit.
   -o <o>
   -p <p>                Port.]], parser:get_help())
   end)

   it("creates correct help message for commands", function()
      local parser = Parser "foo"
      parser:flag "-q --quiet"
      local run = parser:command "run"
         :description "Run! "
      run:option "--where"

      assert.equal([[
Usage: foo [-h] [-q] <command> ...

Options:
   -h, --help            Show this help message and exit.
   -q, --quiet

Commands:
   run                   Run! ]], parser:get_help())
   end)

   it("creates correct help message for subcommands", function()
      local parser = Parser "foo"
      parser:flag "-q" "--quiet"
      local run = parser:command "run"
      run:option "--where"

      assert.equal([[
Usage: foo run [-h] [--where <where>]

Options:
   -h, --help            Show this help message and exit.
   --where <where>]], run:get_help())
   end)

   it("uses message provided by user", function()
      local parser = Parser "foo"
         :help "I don't like your format of help messages"
      parser:flag "-q" "--quiet"

      assert.equal([[
I don't like your format of help messages]], parser:get_help())
   end)

   it("does not mention hidden arguments, options, and commands", function()
      local parser = Parser "foo"
      parser:argument "normal"
      parser:argument "deprecated"
         :args "?"
         :hidden(true)
      parser:flag "--feature"
      parser:flag "--misfeature"
         :hidden(true)
      parser:command "good"
      parser:command "okay"
      parser:command "never-use-this-one"
         :hidden(true)

      assert.equal([[
Usage: foo [-h] [--feature] <normal> <command> ...

Arguments:
   normal

Options:
   -h, --help            Show this help message and exit.
   --feature

Commands:
   good
   okay]], parser:get_help())
   end)

   it("omits categories if all elements are hidden", function()
      local parser = Parser "foo"
         :add_help(false)
      parser:argument "deprecated"
         :args "?"
         :hidden(true)
      parser:flag "--misfeature"
         :hidden(true)

      assert.equal([[
Usage: foo]], parser:get_help())
   end)

   it("does not mention hidden option and command aliases", function()
      local parser = Parser "foo"
      parser:option "--server"
         :hidden_name "--from"
      parser:command "newname"
         :hidden_name "oldname"

      assert.equal([[
Usage: foo [-h] [--server <server>] <command> ...

Options:
   -h, --help            Show this help message and exit.
   --server <server>

Commands:
   newname]], parser:get_help())
   end)

   it("supports grouping options", function()
      local parser = Parser "foo"
         :add_help(false)
      parser:argument "thing"

      parser:group("Options for setting position",
         parser:option "--coords"
            :args(2)
            :argname {"<x>", "<y>"}
            :description "Set coordinates.",
         parser:option "--polar"
            :args(2)
            :argname {"<rad>", "<ang>"}
            :description "Set polar coordinates."
      )

      parser:group("Options for setting style",
         parser:flag "--dotted"
            :description "More dots.",
         parser:option "--width"
            :argname "<px>"
            :description "Set width."
      )

      assert.equal([[
Usage: foo [--coords <x> <y>] [--polar <rad> <ang>] [--dotted]
       [--width <px>] <thing>

Arguments:
   thing

Options for setting position:
   --coords <x> <y>      Set coordinates.
   --polar <rad> <ang>   Set polar coordinates.

Options for setting style:
   --dotted              More dots.
   --width <px>          Set width.]], parser:get_help())
   end)

   it("adds default group with 'other' prefix if not all elements of a type are grouped", function()
      local parser = Parser "foo"

      parser:group("Main arguments",
         parser:argument "foo",
         parser:argument "bar",
         parser:flag "--use-default-args"
      )

      parser:argument "optional"
         :args "?"

      parser:group("Main options",
         parser:flag "--something",
         parser:option "--test"
      )

      parser:flag "--version"

      parser:group("Some commands",
         parser:command "foo",
         parser:command "bar"
      )

      parser:command "another-command"

      assert.equal([[
Usage: foo [-h] [--use-default-args] [--something] [--test <test>]
       [--version] <foo> <bar> [<optional>] <command> ...

Main arguments:
   foo
   bar
   --use-default-args

Other arguments:
   optional

Main options:
   --something
   --test <test>

Other options:
   -h, --help            Show this help message and exit.
   --version

Some commands:
   foo
   bar

Other commands:
   another-command]], parser:get_help())
   end)

   it("allows spacing out element help blocks more with help_vertical_space", function()
      local parser = Parser "foo"
         :help_vertical_space(1)

      parser:argument "arg1"
         :description "Argument number one."
      parser:argument "arg2"
         :description "Argument number two."

      parser:flag "-p"
         :description "This is a thing."
      parser:option "-f --foo"
         :description [[
And this things uses many lines.
Because it has lots of complex behaviour.
That needs documenting.]]

      assert.equal([[
Usage: foo [-h] [-p] [-f <foo>] <arg1> <arg2>

Arguments:

   arg1                  Argument number one.

   arg2                  Argument number two.

Options:

   -h, --help            Show this help message and exit.

   -p                    This is a thing.

      -f <foo>,          And this things uses many lines.
   --foo <foo>           Because it has lots of complex behaviour.
                         That needs documenting.]], parser:get_help())
   end)

   it("inherits help_vertical_space in commands", function()
      local parser = Parser "foo"
         :help_vertical_space(1)

      local cmd1 = parser:command "cmd1"
         :help_vertical_space(2)

      cmd1:flag("-a", "Do a thing.")
      cmd1:flag("-b", "Do b thing.")

      local cmd2 = parser:command "cmd2"

      cmd2:flag("-c", "Do c thing.")
      cmd2:flag("-d", "Do d thing.")

      assert.equal([[
Usage: foo cmd1 [-h] [-a] [-b]

Options:


   -h, --help            Show this help message and exit.


   -a                    Do a thing.


   -b                    Do b thing.]], cmd1:get_help())

      assert.equal([[
Usage: foo cmd2 [-h] [-c] [-d]

Options:

   -h, --help            Show this help message and exit.

   -c                    Do c thing.

   -d                    Do d thing.]], cmd2:get_help())
   end)

   it("allows configuring margins using help_usage_margin and help_description_margin", function()
      local parser = Parser "foo"
         :help_usage_margin(2)
         :help_description_margin(15)

      parser:argument "arg1"
         :description "Argument number one."
      parser:argument "arg2"
         :description "Argument number two."

      parser:flag "-p"
         :description "This is a thing."
      parser:option "-f --foo"
         :description [[
And this things uses many lines.
Because it has lots of complex behaviour.
That needs documenting.]]

      assert.equal([[
Usage: foo [-h] [-p] [-f <foo>] <arg1> <arg2>

Arguments:
  arg1         Argument number one.
  arg2         Argument number two.

Options:
  -h, --help   Show this help message and exit.
  -p           This is a thing.
     -f <foo>, And this things uses many lines.
  --foo <foo>  Because it has lots of complex behaviour.
               That needs documenting.]], parser:get_help())
   end)

   describe("autowrap", function()
      it("automatically wraps descriptions to match given max width", function()
         local parser = Parser "foo"
            :help_max_width(80)

         parser:option "-f --foo"
            :description("Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor " ..
               "incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation " ..
               "ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit " ..
               "in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat " ..
               "non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.")
         parser:option "-b --bar"
            :description "See above."

         assert.equal([[
Usage: foo [-h] [-f <foo>] [-b <bar>]

Options:
   -h, --help            Show this help message and exit.
      -f <foo>,          Lorem ipsum dolor sit amet, consectetur adipiscing
   --foo <foo>           elit, sed do eiusmod tempor incididunt ut labore et
                         dolore magna aliqua. Ut enim ad minim veniam, quis
                         nostrud exercitation ullamco laboris nisi ut aliquip ex
                         ea commodo consequat. Duis aute irure dolor in
                         reprehenderit in voluptate velit esse cillum dolore eu
                         fugiat nulla pariatur. Excepteur sint occaecat
                         cupidatat non proident, sunt in culpa qui officia
                         deserunt mollit anim id est laborum.
      -b <bar>,          See above.
   --bar <bar>]], parser:get_help())
      end)

      it("preserves existing line breaks", function()
         local parser = Parser "foo"
            :help_max_width(80)

         parser:option "-f --foo"
            :description("This is a long line, it should be broken down into several lines. " .. [[
It just keeps going and going.
This should always be a new line.
Another one.
]])
         parser:option "-b --bar"

         assert.equal([[
Usage: foo [-h] [-f <foo>] [-b <bar>]

Options:
   -h, --help            Show this help message and exit.
      -f <foo>,          This is a long line, it should be broken down into
   --foo <foo>           several lines. It just keeps going and going.
                         This should always be a new line.
                         Another one.
      -b <bar>,
   --bar <bar>]], parser:get_help())
      end)

      it("preserves indentation", function()
         local parser = Parser "foo"
            :help_max_width(80)

         parser:option "-f --foo"
            :description("This is a long line, it should be broken down into several lines.\n" ..
               "   This paragraph is indented with three spaces, so when it gets broken down into several lines, " ..
               "they will be, too.\n\n" ..
               "  That was an empty line there, preserve it.")

         assert.equal([[
Usage: foo [-h] [-f <foo>]

Options:
   -h, --help            Show this help message and exit.
      -f <foo>,          This is a long line, it should be broken down into
   --foo <foo>           several lines.
                            This paragraph is indented with three spaces, so
                            when it gets broken down into several lines, they
                            will be, too.

                           That was an empty line there, preserve it.]], parser:get_help())
      end)

      it("preserves indentation of list items", function()
         local parser = Parser "foo"
            :help_max_width(80)

         parser:option "-f --foo"
            :description("Let's start a list:\n\n" ..
               "* Here is a list item.\n" ..
               "* Here is another one, this one is very long so it needs several lines. More words. Word. Word.\n" ..
               "  + Here is a nested list item. Word. Word. Word. Word. Word. Bird. Word. Bird. Bird. Bird.\n" ..
               "*   Back to normal list, this one uses several spaces after the list item mark. Bird. Bird. Bird.")


      assert.equal([[
Usage: foo [-h] [-f <foo>]

Options:
   -h, --help            Show this help message and exit.
      -f <foo>,          Let's start a list:
   --foo <foo>
                         * Here is a list item.
                         * Here is another one, this one is very long so it
                           needs several lines. More words. Word. Word.
                           + Here is a nested list item. Word. Word. Word. Word.
                             Word. Bird. Word. Bird. Bird. Bird.
                         *   Back to normal list, this one uses several spaces
                             after the list item mark. Bird. Bird. Bird.]], parser:get_help())
      end)

      it("preserves multiple spaces between words", function()
         local parser = Parser "foo"
            :help_max_width(80)

         parser:option "-f --foo"
            :description("This  is  a  long  line  with  two  spaces  between  words,  it  should  be  broken  down.")

         assert.equal([[
Usage: foo [-h] [-f <foo>]

Options:
   -h, --help            Show this help message and exit.
      -f <foo>,          This  is  a  long  line  with  two  spaces  between
   --foo <foo>           words,  it  should  be  broken  down.]], parser:get_help())
      end)

      it("autowraps description and epilog", function()
         local parser = Parser "foo"
            :help_max_width(80)
            :description("Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor " ..
               "incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation " ..
               "ullamco laboris nisi ut aliquip ex ea commodo consequat.")
            :epilog("Duis aute irure dolor in reprehenderit " ..
               "in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat " ..
               "non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.")

         assert.equal([[
Usage: foo [-h]

Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor
incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis
nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.

Options:
   -h, --help            Show this help message and exit.

Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu
fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in
culpa qui officia deserunt mollit anim id est laborum.]], parser:get_help())
      end)
   end)
end)
