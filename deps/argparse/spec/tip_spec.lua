local Parser = require "argparse"
getmetatable(Parser()).error = function(_, msg) error(msg) end

describe("tests related to tips", function()
   describe("provides tips when data is too long", function()
      it("for options", function()
         local parser = Parser()
         parser:option "-q" "--quiet"

         assert.has_error(function() parser:parse{"--quiett=true"} end,
            "unknown option '--quiett'\nDid you mean '--quiet'?")
      end)

      it("for commands", function()
         local parser = Parser "name"
         parser:command "install"

         assert.has_error(function() parser:parse{"installq"} end,
            "unknown command 'installq'\nDid you mean 'install'?")
      end)
   end)

   describe("provides tips when data is too short", function()
      it("for options", function()
         local parser = Parser()
         parser:option "-q" "--quiet"

         assert.has_error(function() parser:parse{"--quet=true"} end,
            "unknown option '--quet'\nDid you mean '--quiet'?")
      end)

      it("for commands", function()
         local parser = Parser "name"
         parser:command "install"

         assert.has_error(function() parser:parse{"nstall"} end,
            "unknown command 'nstall'\nDid you mean 'install'?")
      end)
   end)

   describe("provides tips on substitution", function()
      it("for options", function()
         local parser = Parser()
         parser:option "-q" "--quiet"

         assert.has_error(function() parser:parse{"--qriet=true"} end,
            "unknown option '--qriet'\nDid you mean '--quiet'?")
      end)

      it("for commands", function()
         local parser = Parser "name"
         parser:command "install"

         assert.has_error(function() parser:parse{"inntall"} end,
            "unknown command 'inntall'\nDid you mean 'install'?")
      end)
   end)

   describe("provides tips on transpositions", function()
      it("for options", function()
         local parser = Parser()
         parser:option "-q" "--quiet"

         assert.has_error(function() parser:parse{"--queit=true"} end,
            "unknown option '--queit'\nDid you mean '--quiet'?")
      end)

      it("for commands", function()
         local parser = Parser "name"
         parser:command "install"

         assert.has_error(function() parser:parse{"isntall"} end,
            "unknown command 'isntall'\nDid you mean 'install'?")
      end)
   end)

   describe("provides multiple tips", function()
      it("for options", function()
         local parser = Parser()
         parser:option "-q" "--quiet"
         parser:option "--quick"

         assert.has_error(function() parser:parse{"--quiec=true"} end,
            "unknown option '--quiec'\nDid you mean one of these: '--quick' '--quiet'?")
      end)

      it("for commands", function()
         local parser = Parser "name"
         parser:command "install"
         parser:command "instant"

         assert.has_error(function() parser:parse{"instanl"} end,
            "unknown command 'instanl'\nDid you mean one of these: 'install' 'instant'?")
      end)
   end)
end)
