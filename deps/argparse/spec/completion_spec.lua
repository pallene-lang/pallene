local script = "./spec/comptest"
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

describe("tests related to generation of shell completion scripts", function()
   it("generates correct bash completion script", function()
      assert.equal([=[
_comptest() {
    local IFS=$' \t\n'
    local args cur prev cmd opts arg
    args=("${COMP_WORDS[@]}")
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
    opts="-h --help --completion -v --verbose -f --files"

    case "$prev" in
        --completion)
            COMPREPLY=($(compgen -W "bash zsh fish" -- "$cur"))
            return 0
            ;;
        -f|--files)
            COMPREPLY=($(compgen -f -- "$cur"))
            return 0
            ;;
    esac

    args=("${args[@]:1}")
    for arg in "${args[@]}"; do
        case "$arg" in
            help)
                cmd="help"
                opts="$opts -h --help"
                break
                ;;
            completion)
                cmd="completion"
                opts="$opts -h --help"
                break
                ;;
            install|i)
                cmd="install"
                opts="$opts -h --help --deps-mode --no-doc"
                break
                ;;
            admin)
                cmd="admin"
                opts="$opts -h --help"
                args=("${args[@]:1}")
                for arg in "${args[@]}"; do
                    case "$arg" in
                        help)
                            cmd="$cmd help"
                            opts="$opts -h --help"
                            break
                            ;;
                        add)
                            cmd="$cmd add"
                            opts="$opts -h --help"
                            break
                            ;;
                        remove)
                            cmd="$cmd remove"
                            opts="$opts -h --help"
                            break
                            ;;
                    esac
                done
                break
                ;;
        esac
    done

    case "$cmd" in
        '')
            COMPREPLY=($(compgen -W "help completion install i admin" -- "$cur"))
            ;;
        'help')
            COMPREPLY=($(compgen -W "help completion install i admin" -- "$cur"))
            ;;
        'install')
            case "$prev" in
                --deps-mode)
                    COMPREPLY=($(compgen -W "all one order none" -- "$cur"))
                    return 0
                    ;;
            esac

            ;;
        'admin')
            COMPREPLY=($(compgen -W "help add remove" -- "$cur"))
            ;;
        'admin help')
            COMPREPLY=($(compgen -W "help add remove" -- "$cur"))
            ;;
    esac

    if [[ "$cur" = -* ]]; then
        COMPREPLY=($(compgen -W "$opts" -- "$cur"))
    fi
}

complete -F _comptest -o bashdefault -o default comptest
]=], get_output("completion bash"))
   end)

   it("generates correct zsh completion script", function()
      assert.equal([=[
#compdef comptest

_comptest() {
  local context state state_descr line
  typeset -A opt_args

  local -a options=(
    {-h,--help}"[Show this help message and exit]"
    "--completion[Output a shell completion script for the specified shell]: :(bash zsh fish)"
    "*"{-v,--verbose}"[Set the verbosity level]"
    {-f,--files}"[A description with illegal \"' characters]:*: :_files"
  )
  _arguments -s -S \
    $options \
    ": :_comptest_cmds" \
    "*:: :->args" \
    && return 0

  case $words[1] in
    help)
      options=(
        $options
        {-h,--help}"[Show this help message and exit]"
      )
      _arguments -s -S \
        $options \
        ": :(help completion install i admin)" \
        && return 0
      ;;

    completion)
      options=(
        $options
        {-h,--help}"[Show this help message and exit]"
      )
      _arguments -s -S \
        $options \
        ": :(bash zsh fish)" \
        && return 0
      ;;

    install|i)
      options=(
        $options
        {-h,--help}"[Show this help message and exit]"
        "--deps-mode: :(all one order none)"
        "--no-doc[Install without documentation]"
      )
      _arguments -s -S \
        $options \
        && return 0
      ;;

    admin)
      options=(
        $options
        {-h,--help}"[Show this help message and exit]"
      )
      _arguments -s -S \
        $options \
        ": :_comptest_admin_cmds" \
        "*:: :->args" \
        && return 0

      case $words[1] in
        help)
          options=(
            $options
            {-h,--help}"[Show this help message and exit]"
          )
          _arguments -s -S \
            $options \
            ": :(help add remove)" \
            && return 0
          ;;

        add)
          options=(
            $options
            {-h,--help}"[Show this help message and exit]"
          )
          _arguments -s -S \
            $options \
            ": :_files" \
            && return 0
          ;;

        remove)
          options=(
            $options
            {-h,--help}"[Show this help message and exit]"
          )
          _arguments -s -S \
            $options \
            ": :_files" \
            && return 0
          ;;

      esac
      ;;

  esac

  return 1
}

_comptest_cmds() {
  local -a commands=(
    "help:Show help for commands"
    "completion:Output a shell completion script"
    {install,i}":Install a rock"
    "admin:Rock server administration interface"
  )
  _describe "command" commands
}

_comptest_admin_cmds() {
  local -a commands=(
    "help:Show help for commands"
    "add:Add a rock to a server"
    "remove:Remove a rock from  a server"
  )
  _describe "command" commands
}

_comptest
]=], get_output("completion zsh"))
   end)

   it("generates correct fish completion script", function()
      assert.equal([=[
function __fish_comptest_print_command
    set -l cmdline (commandline -poc)
    set -l cmd
    set -e cmdline[1]
    for arg in $cmdline
        switch $arg
            case help
                set cmd $cmd help
                break
            case completion
                set cmd $cmd completion
                break
            case install i
                set cmd $cmd install
                break
            case admin
                set cmd $cmd admin
                set -e cmdline[1]
                for arg in $cmdline
                    switch $arg
                        case help
                            set cmd $cmd help
                            break
                        case add
                            set cmd $cmd add
                            break
                        case remove
                            set cmd $cmd remove
                            break
                    end
                end
                break
        end
    end
    echo "$cmd"
end

function __fish_comptest_using_command
    test (__fish_comptest_print_command) = "$argv"
    and return 0
    or return 1
end

function __fish_comptest_seen_command
    string match -q "$argv*" (__fish_comptest_print_command)
    and return 0
    or return 1
end

complete -c comptest -n '__fish_comptest_using_command' -xa 'help' -d 'Show help for commands'
complete -c comptest -n '__fish_comptest_using_command' -xa 'completion' -d 'Output a shell completion script'
complete -c comptest -n '__fish_comptest_using_command' -xa 'install i' -d 'Install a rock'
complete -c comptest -n '__fish_comptest_using_command' -xa 'admin' -d 'Rock server administration interface'
complete -c comptest -s h -l help -d 'Show this help message and exit'
complete -c comptest -l completion -xa 'bash zsh fish' -d 'Output a shell completion script for the specified shell'
complete -c comptest -s v -l verbose -d 'Set the verbosity level'
complete -c comptest -s f -l files -r -d 'A description with illegal "\' characters'

complete -c comptest -n '__fish_comptest_using_command help' -xa 'help completion install i admin'
complete -c comptest -n '__fish_comptest_seen_command help' -s h -l help -d 'Show this help message and exit'

complete -c comptest -n '__fish_comptest_seen_command completion' -s h -l help -d 'Show this help message and exit'

complete -c comptest -n '__fish_comptest_seen_command install' -s h -l help -d 'Show this help message and exit'
complete -c comptest -n '__fish_comptest_seen_command install' -l deps-mode -xa 'all one order none'
complete -c comptest -n '__fish_comptest_seen_command install' -l no-doc -d 'Install without documentation'

complete -c comptest -n '__fish_comptest_using_command admin' -xa 'help' -d 'Show help for commands'
complete -c comptest -n '__fish_comptest_using_command admin' -xa 'add' -d 'Add a rock to a server'
complete -c comptest -n '__fish_comptest_using_command admin' -xa 'remove' -d 'Remove a rock from  a server'
complete -c comptest -n '__fish_comptest_seen_command admin' -s h -l help -d 'Show this help message and exit'

complete -c comptest -n '__fish_comptest_using_command admin help' -xa 'help add remove'
complete -c comptest -n '__fish_comptest_seen_command admin help' -s h -l help -d 'Show this help message and exit'

complete -c comptest -n '__fish_comptest_seen_command admin add' -s h -l help -d 'Show this help message and exit'

complete -c comptest -n '__fish_comptest_seen_command admin remove' -s h -l help -d 'Show this help message and exit'
]=], get_output("completion fish"))
   end)
end)
