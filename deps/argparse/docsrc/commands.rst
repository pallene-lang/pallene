Adding and configuring commands
===============================

A command is a subparser invoked when its name is passed as an argument. For example, in `git <http://git-scm.com>`_ CLI ``add``, ``commit``, ``push``, etc. are commands. Each command has its own set of arguments and options, but inherits options of its parent.

Commands can be added using ``:command(name, description, epilog)`` method. Just as options, commands can have several aliases.

.. code-block:: lua
   :linenos:

   parser:command "install i"

If a command it used, ``true`` is stored in the corresponding field of the result table.

.. code-block:: none

   $ lua script.lua install

.. code-block:: lua

   {
      install = true
   }

A typo will result in an appropriate error message.

.. code-block:: none

   $ lua script.lua instal

.. code-block:: none

   Usage: script.lua [-h] <command> ...

   Error: unknown command 'instal'
   Did you mean 'install'?

Getting name of selected command
--------------------------------

Use ``command_target`` property of the parser to store the name of used command in a field of the result table.

.. code-block:: lua
   :linenos:

   parser:command_target("command")
   parser:command("install")
   parser:command("remove")

.. code-block:: none

   $ lua script.lua install

.. code-block:: lua

   {
      install = true,
      command = "install"
   }

Adding elements to commands
---------------------------

The Command class is a subclass of the Parser class, so all the Parser's methods for adding elements work on commands, too.

.. code-block:: lua
   :linenos:

   local install = parser:command "install"
   install:argument "rock"
   install:option "-f --from"

.. code-block:: none

   $ lua script.lua install foo --from=bar


.. code-block:: lua

   {
      install = true,
      rock = "foo",
      from = "bar"
   }

Commands have their own usage and help messages.

.. code-block:: none

   $ lua script.lua install

.. code-block:: none

   Usage: script.lua install [-h] [-f <from>] <rock>

   Error: too few arguments

.. code-block:: none

   $ lua script.lua install --help

.. code-block:: none

   Usage: script.lua install [-h] [-f <from>] <rock>

   Arguments:
      rock

   Options:
      -h, --help            Show this help message and exit.
      -f <from>, --from <from>

Making a command optional
-------------------------

By default, if a parser has commands, using one of them is obligatory.


.. code-block:: lua
   :linenos:

   local parser = argparse()
   parser:command "install"

.. code-block:: none

   $ lua script.lua

.. code-block:: none

   Usage: script.lua [-h] <command> ...

   Error: a command is required

This can be changed using ``require_command`` property.

.. code-block:: lua
   :linenos:

   local parser = argparse()
      :require_command(false)
   parser:command "install"

Command summaries
-----------------

The description for commands shown in the parent parser help message can be set
with the ``summary`` property.

.. code-block:: lua
   :linenos:

   parser:command "install"
      :summary "Install a rock."
      :description "A long description for the install command."

.. code-block:: none

   $ lua script.lua --help

.. code-block:: none

   Usage: script.lua [-h] <command> ...

   Options:
      -h, --help            Show this help message and exit.

   Commands:
      install               Install a rock.

.. code-block:: none

   $ lua script.lua install --help

.. code-block:: none

   Usage: script.lua install [-h]

   A long description for the install command.

   Options:
      -h, --help            Show this help message and exit.
