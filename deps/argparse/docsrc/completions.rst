Shell completions
=================

Argparse can generate shell completion scripts for
`Bash <https://www.gnu.org/software/bash/>`_, `Zsh <https://www.zsh.org/>`_, and
`Fish <https://fishshell.com/>`_.
The completion scripts support completing options, commands, and argument
choices.

The Parser methods ``:get_bash_complete()``, ``:get_zsh_complete()``, and
``:get_fish_complete()`` return completion scripts as a string.

Adding a completion option or command
-------------------------------------

A ``--completion`` option can be added to a parser using the
``:add_complete([value])`` method. The optional ``value`` argument is a string
or table used to configure the option (by calling the option with ``value``).

.. code-block:: lua
   :linenos:

   local parser = argparse()
      :add_complete()

.. code-block:: none

   $ lua script.lua -h

.. code-block:: none

   Usage: script.lua [-h] [--completion {bash,zsh,fish}]

   Options:
      -h, --help            Show this help message and exit.
      --completion {bash,zsh,fish}
                            Output a shell completion script for the specified shell.

A similar ``completion`` command can be added to a parser using the
``:add_complete_command([value])`` method.

Using completions
-----------------

Bash
^^^^

Save the generated completion script at
``/usr/share/bash-completion/completions/script.lua`` or
``~/.local/share/bash-completion/completions/script.lua``.

Alternatively, add the following line to the ``~/.bashrc``:

.. code-block:: bash

   source <(script.lua --completion bash)

Zsh
^^^

Save the completion script in the ``/usr/share/zsh/site-functions/`` directory
or any directory in the ``$fpath``. The file name should be an underscore
followed by the program name. A new directory can be added to to the ``$fpath``
by adding e.g. ``fpath=(~/.zfunc $fpath)`` in the ``~/.zshrc`` before
``compinit``.

Fish
^^^^

Save the completion script at
``/usr/share/fish/vendor_completions.d/script.lua.fish`` or
``~/.config/fish/completions/script.lua.fish``.

Alternatively, add the following line to the file ``~/.config/fish/config.fish``:

.. code-block:: fish

   script.lua --completion fish | source
