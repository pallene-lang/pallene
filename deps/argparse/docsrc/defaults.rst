Default values
==============

For elements such as arguments and options, if ``default`` property is set to a string, its value is stored in case the element was not used (if it's not a string, it'll be used as ``init`` property instead, see :ref:`actions`).

.. code-block:: lua
   :linenos:

   parser:option("-o --output", "Output file.", "a.out")
   -- Equivalent:
   parser:option "-o" "--output"
      :description "Output file."
      :default "a.out"

.. code-block:: none

   $ lua script.lua

.. code-block:: lua

   {
      output = "a.out"
   }

The existence of a default value is reflected in help message, unless ``show_default`` property is set to ``false``.

.. code-block:: none

   $ lua script.lua --help

.. code-block:: none

   Usage: script.lua [-h] [-o <output>]

   Options: 
      -h, --help            Show this help message and exit.
      -o <output>, --output <output>
                            Output file. (default: a.out)

Note that invocation without required arguments is still an error.

.. code-block:: none

   $ lua script.lua -o

.. code-block:: none

   Usage: script.lua [-h] [-o <output>]

   Error: too few arguments

Default mode
------------

``defmode`` property regulates how argparse should use the default value of an element.

By default, or if ``defmode`` contains ``u`` (for unused), the default value will be automatically passed to the element if it was not invoked at all.
It will be passed minimal required of times, so that if the element is allowed to consume no arguments (e.g. using ``:args "?"``), the default value is ignored.

If ``defmode`` contains ``a`` (for argument), the default value will be automatically passed to the element if not enough arguments were passed, or not enough invocations were made.

Consider the difference:

.. code-block:: lua
   :linenos:

   parser:option "-o"
      :default "a.out"
   parser:option "-p" 
      :default "password"
      :defmode "arg"

.. code-block:: none

   $ lua script.lua -h

.. code-block:: none

   Usage: script.lua [-h] [-o <o>] [-p [<p>]]

   Options:
      -h, --help            Show this help message and exit.
      -o <o>                default: a.out
      -p [<p>]              default: password

.. code-block:: none

   $ lua script.lua

.. code-block:: lua

   {
      o = "a.out"
   }

.. code-block:: none

   $ lua script.lua -p


.. code-block:: lua

   {
      o = "a.out",
      p = "password"
   }

.. code-block:: none

   $ lua script.lua -o

.. code-block:: none

   Usage: script.lua [-h] [-o <o>] [-p [<p>]]

   Error: too few arguments
