Adding and configuring options
==============================

Options can be added using ``:option(name, description, default, convert, args, count)`` method. It returns an Option instance, which can be configured in the same way as Parsers. The ``name`` property is required. An option can have several aliases, which can be set as space separated substrings in its name or by continuously setting ``name`` property.

.. code-block:: lua
   :linenos:

   -- These lines are equivalent:
   parser:option "-f" "--from"
   parser:option "-f --from"

.. code-block:: none

   $ lua script.lua --from there
   $ lua script.lua --from=there
   $ lua script.lua -f there
   $ lua script.lua -fthere

.. code-block:: lua

   {
      from = "there"
   }

For an option, default index used to store arguments passed to it is the first "long" alias (an alias starting with two control characters, typically hyphens) or just the first alias, without control characters. Hyphens in the default index are replaced with underscores. In the following table it is assumed that ``local args = parser:parse()`` has been executed.

======================== ==============================
Option's aliases         Location of option's arguments
======================== ==============================
``-o``                   ``args.o``
``-o`` ``--output``      ``args.output``
``-s`` ``--from-server`` ``args.from_server``
======================== ==============================

As with arguments, the index can be explicitly set using ``target`` property.

Flags
-----

Flags are almost identical to options, except that they don't take an argument by default.

.. code-block:: lua
   :linenos:

   parser:flag("-q --quiet")

.. code-block:: none

   $ lua script.lua -q

.. code-block:: lua

   {
      quiet = true
   }

Control characters
------------------

The first characters of all aliases of all options of a parser form the set of control characters, used to distinguish options from arguments. Typically the set only consists of a hyphen.

Setting number of consumed arguments
------------------------------------

Just as arguments, options can be configured to take several command line arguments.

.. code-block:: lua
   :linenos:

   parser:option "--pair"
      :args(2)
   parser:option "--optional"
      :args "?"

.. code-block:: none

   $ lua script.lua --pair foo bar

.. code-block:: lua

   {
      pair = {"foo", "bar"}
   }

.. code-block:: none

   $ lua script.lua --pair foo bar --optional

.. code-block:: lua

   {
      pair = {"foo", "bar"},
      optional = {}
   }

.. code-block:: none

   $ lua script.lua --optional=baz

.. code-block:: lua

   {
      optional = {"baz"}
   }


Note that the data passed to ``optional`` option is stored in an array. That is necessary to distinguish whether the option was invoked without an argument or it was not invoked at all.

Setting argument choices
------------------------

The ``choices`` property can be used to specify a list of choices for an option argument in the same way as for arguments.

.. code-block:: lua
   :linenos:

   parser:option "--format"
      :choices {"short", "medium", "full"}

.. code-block:: none

   $ lua script.lua --format foo

.. code-block:: none

   Usage: script.lua [-h] [--format {short,medium,full}]

   Error: argument for option '--format' must be one of 'short', 'medium', 'full'

Setting number of invocations
-----------------------------

For options, it is possible to control how many times they can be used. argparse uses ``count`` property to set how many times an option can be invoked. The value of the property is interpreted in the same way ``args`` is.

.. code-block:: lua
   :linenos:

   parser:option("-e --exclude")
      :count "*"

.. code-block:: none

   $ lua script.lua -eFOO -eBAR

.. code-block:: lua

   {
      exclude = {"FOO", "BAR"}
   }

If an option can be used more than once and it can consume more than one argument, the data is stored as an array of invocations, each being an array of arguments.

As a special case, if an option can be used more than once and it consumes no arguments (e.g. it's a flag), than the number of invocations is stored in the associated field of the result table.

.. code-block:: lua
   :linenos:

   parser:flag("-v --verbose", "Sets verbosity level.")
      :count "0-2"
      :target "verbosity"

.. code-block:: none

   $ lua script.lua -vv

.. code-block:: lua

   {
      verbosity = 2
   }
