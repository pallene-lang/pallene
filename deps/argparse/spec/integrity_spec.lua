local script = "./spec/script.lua"
local script_cmd = "lua"

if package.loaded["luacov.runner"] then
   script_cmd = script_cmd .. " -lluacov"
end

script_cmd = script_cmd .. " " .. script

local function get_output(args)
   local handler = io.popen(script_cmd .. " " .. args .. " 2>&1", "r")
   local output = handler:read("*a")
   handler:close()
   return output
end

describe("tests related to CLI behaviour #unsafe", function()
   describe("error messages", function()
      it("generates correct error message without arguments", function()
         assert.equal([[
Usage: ]]..script..[[ [-h] [-v] <input> [<command>] ...

Error: missing argument 'input'
]], get_output(""))
      end)

      it("generates correct error message with too many arguments", function()
         assert.equal([[
Usage: ]]..script..[[ [-h] [-v] <input> [<command>] ...

Error: unknown command 'bar'
]], get_output("foo bar"))
      end)

      it("generates correct error message with unexpected argument", function()
         assert.equal([[
Usage: ]]..script..[[ [-h] [-v] <input> [<command>] ...

Error: option '--verbose' does not take arguments
]], get_output("--verbose=true"))
      end)

      it("generates correct error message with unexpected option", function()
         assert.equal([[
Usage: ]]..script..[[ [-h] [-v] <input> [<command>] ...

Error: unknown option '-q'
Did you mean one of these: '-h' '-v'?
]], get_output("-vq"))
      end)

      it("generates correct error message and tip with unexpected command", function()
         assert.equal([[
Usage: ]]..script..[[ [-h] [-v] <input> [<command>] ...

Error: unknown command 'nstall'
Did you mean 'install'?
]], get_output("foo nstall"))
      end)

      it("generates correct error message without arguments in command", function()
         assert.equal([[
Usage: ]]..script..[[ install [-h] [-f <from>] <rock> [<version>]

Error: missing argument 'rock'
]], get_output("foo install"))
      end)

      it("generates correct error message and tip in command", function()
         assert.equal([[
Usage: ]]..script..[[ install [-h] [-f <from>] <rock> [<version>]

Error: unknown option '--form'
Did you mean '--from'?
]], get_output("foo install bar --form=there"))
      end)
   end)

   describe("help messages", function()
      it("generates correct help message using help flag", function()
         assert.equal([[
Usage: ]]..script..[[ [-h] [-v] <input> [<command>] ...

A testing program.

Arguments:
   input

Options:
   -h, --help            Show this help message and exit.
   -v, --verbose         Sets verbosity level.

Commands:
   help                  Show help for commands.
   install               Install a rock.
]], get_output("--help"))
      end)

      it("generates correct help message using help command", function()
         assert.equal([[
Usage: ]]..script..[[ [-h] [-v] <input> [<command>] ...

A testing program.

Arguments:
   input

Options:
   -h, --help            Show this help message and exit.
   -v, --verbose         Sets verbosity level.

Commands:
   help                  Show help for commands.
   install               Install a rock.
]], get_output("foo help"))
      end)

      it("generates correct help message for command using help flag", function()
         assert.equal([[
Usage: ]]..script..[[ install [-h] [-f <from>] <rock> [<version>]

Install a rock.

Arguments:
   rock                  Name of the rock.
   version               Version of the rock.

Options:
   -h, --help            Show this help message and exit.
       -f <from>,        Fetch the rock from this server.
   --from <from>
]], get_output("foo install --help"))
      end)

      it("generates correct help message for command using help command", function()
         assert.equal([[
Usage: ]]..script..[[ install [-h] [-f <from>] <rock> [<version>]

Install a rock.

Arguments:
   rock                  Name of the rock.
   version               Version of the rock.

Options:
   -h, --help            Show this help message and exit.
       -f <from>,        Fetch the rock from this server.
   --from <from>
]], get_output("foo help install"))
      end)
   end)

   describe("data flow", function()
      it("works with one argument", function()
         local handler = io.popen(script_cmd .. " foo 2>&1", "r")
         assert.equal("foo", handler:read "*l")
         assert.equal("0", handler:read "*l")
         handler:close()
      end)

      it("works with one argument and a flag", function()
         local handler = io.popen(script_cmd .. " -v foo --verbose 2>&1", "r")
         assert.equal("foo", handler:read "*l")
         assert.equal("2", handler:read "*l")
         handler:close()
      end)

      it("works with command", function()
         local handler = io.popen(script_cmd .. " foo -v install bar 2>&1", "r")
         assert.equal("foo", handler:read "*l")
         assert.equal("1", handler:read "*l")
         assert.equal("true", handler:read "*l")
         assert.equal("bar", handler:read "*l")
         assert.equal("nil", handler:read "*l")
         assert.equal("nil", handler:read "*l")
         handler:close()
      end)

      it("works with command and options", function()
         local handler = io.popen(script_cmd .. " foo --verbose install bar 0.1 --from=there -vv 2>&1", "r")
         assert.equal("foo", handler:read "*l")
         assert.equal("2", handler:read "*l")
         assert.equal("true", handler:read "*l")
         assert.equal("bar", handler:read "*l")
         assert.equal("0.1", handler:read "*l")
         assert.equal("there", handler:read "*l")
         handler:close()
      end)
   end)
end)
