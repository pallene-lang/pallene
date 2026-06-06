Miscellaneous
=============

Argparse version
----------------

``argparse`` module is a table with ``__call`` metamethod. ``argparse.version`` is a string in ``MAJOR.MINOR.PATCH`` format specifying argparse version.

Overwriting default help option
-------------------------------

If the property ``add_help`` of a parser is set to ``false``, no help option will be added to it. Otherwise, the value of the field will be used to configure it.

.. code-block:: lua
   :linenos:

   local parser = argparse()
      :add_help "/?"

.. code-block:: none

   $ lua script.lua /?

.. code-block:: none

   Usage: script.lua [/?]

   Options:
      /?                    Show this help message and exit.

Help command
------------

A help command can be added to the parser using the ``:add_help_command([value])`` method. It accepts an optional string or table value which is used to configure the command.

.. code-block:: lua
   :linenos:

   local parser = argparse()
      :add_help_command()
   parser:command "install"
      :description "Install a rock."

.. code-block:: none

   $ lua script.lua help

.. code-block:: none

   Usage: script.lua [-h] <command> ...

   Options:
      -h, --help            Show this help message and exit.

   Commands:
      help                  Show help for commands.
      install               Install a rock.

.. code-block:: none

   $ lua script.lua help install

.. code-block:: none

   Usage: script.lua install [-h]

   Install a rock.

   Options:
      -h, --help            Show this help message and exit.

Disabling option handling
-------------------------

When ``handle_options`` property of a parser or a command is set to ``false``, all options will be passed verbatim to the argument list, as if the input included double-hyphens.

.. code-block:: lua
   :linenos:

   parser:handle_options(false)
   parser:argument "input"
      :args "*"
   parser:option "-f" "--foo"
      :args "*"

.. code-block:: none

   $ lua script.lua bar -f --foo bar

.. code-block:: lua

   {
      input = {"bar", "-f", "--foo", "bar"}
   }

Prohibiting overuse of options
------------------------------

By default, if an option is invoked too many times, latest invocations overwrite the data passed earlier.

.. code-block:: lua
   :linenos:

   parser:option "-o --output"

.. code-block:: none

   $ lua script.lua -oFOO -oBAR

.. code-block:: lua

   {
      output = "BAR"
   }

Set ``overwrite`` property to ``false`` to prohibit this behavior.

.. code-block:: lua
   :linenos:

   parser:option "-o --output"
      :overwrite(false)

.. code-block:: none

   $ lua script.lua -oFOO -oBAR

.. code-block:: none

   Usage: script.lua [-h] [-o <output>]

   Error: option '-o' must be used at most 1 time

Parsing algorithm
-----------------

argparse interprets command line arguments in the following way:

============= ================================================================================================================
Argument      Interpretation
============= ================================================================================================================
``foo``       An argument of an option or a positional argument.
``--foo``     An option.
``--foo=bar`` An option and its argument. The option must be able to take arguments.
``-f``        An option.
``-abcdef``   Letters are interpreted as options. If one of them can take an argument, the rest of the string is passed to it.
``--``        The rest of the command line arguments will be interpreted as positional arguments.
============= ================================================================================================================

Property lists
--------------

Parser properties
^^^^^^^^^^^^^^^^^

Properties that can be set as arguments when calling or constructing a parser, in this order:

=============== ======
Property        Type
=============== ======
``name``        String
``description`` String
``epilog``      String
=============== ======

Other properties:

=========================== ==========================
Property                    Type
=========================== ==========================
``usage``                   String
``help``                    String
``require_command``         Boolean
``handle_options``          Boolean
``add_help``                Boolean or string or table
``command_target``          String
``usage_max_width``         Number
``usage_margin``            Number
``help_max_width``          Number
``help_usage_margin``       Number
``help_description_margin`` Number
``help_vertical_space``     Number
=========================== ==========================

Command properties
^^^^^^^^^^^^^^^^^^

Properties that can be set as arguments when calling or constructing a command, in this order:

=============== ======
Property        Type
=============== ======
``name``        String
``description`` String
``epilog``      String
=============== ======

Other properties:

=========================== ==========================
Property                    Type
=========================== ==========================
``hidden_name``             String
``summary``                 String
``target``                  String
``usage``                   String
``help``                    String
``require_command``         Boolean
``handle_options``          Boolean
``action``                  Function
``add_help``                Boolean or string or table
``command_target``          String
``hidden``                  Boolean
``usage_max_width``         Number
``usage_margin``            Number
``help_max_width``          Number
``help_usage_margin``       Number
``help_description_margin`` Number
``help_vertical_space``     Number
=========================== ==========================

Argument properties
^^^^^^^^^^^^^^^^^^^

Properties that can be set as arguments when calling or constructing an argument, in this order:

=============== =================
Property        Type
=============== =================
``name``        String
``description`` String
``default``     Any
``convert``     Function or table
``args``        Number or string
=============== =================

Other properties:

=================== ===============
Property            Type
=================== ===============
``target``          String
``defmode``         String
``show_default``    Boolean
``argname``         String or table
``choices``         Table
``action``          Function or string
``init``            Any
``hidden``          Boolean
=================== ===============

Option and flag properties
^^^^^^^^^^^^^^^^^^^^^^^^^^

Properties that can be set as arguments when calling or constructing an option or a flag, in this order:

=============== =================
Property        Type
=============== =================
``name``        String
``description`` String
``default``     Any
``convert``     Function or table
``args``        Number or string
``count``       Number or string
=============== =================

Other properties:

=================== ==================
Property            Type
=================== ==================
``hidden_name``     String
``target``          String
``defmode``         String
``show_default``    Boolean
``overwrite``       Booleans
``argname``         String or table
``choices``         Table
``action``          Function or string
``init``            Any
``hidden``          Boolean
=================== ==================
