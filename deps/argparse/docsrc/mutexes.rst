Mutually exclusive groups
=========================

A group of arguments and options can be marked as mutually exclusive using ``:mutex(argument_or_option, ...)`` method of the Parser class.

.. code-block:: lua
   :linenos:

   parser:mutex(
      parser:argument "input"
         :args "?",
      parser:flag "--process-stdin"
   )

   parser:mutex(
      parser:flag "-q --quiet",
      parser:flag "-v --verbose"
   )

If more than one element of a mutually exclusive group is used, an error is raised.

.. code-block:: none

   $ lua script.lua -qv

.. code-block:: none

   Usage: script.lua ([-q] | [-v]) [-h] ([<input>] | [--process-stdin])

   Error: option '-v' can not be used together with option '-q'

.. code-block:: none

   $ lua script.lua file --process-stdin

.. code-block:: none

   Usage: script.lua ([-q] | [-v]) [-h] ([<input>] | [--process-stdin])

   Error: option '--process-stdin' can not be used together with argument 'input'
