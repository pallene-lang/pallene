# Titan Language Reference

## Types

### Basic Types

- `nil`
- `boolean`
- `integer`
- `float`
- `string`

### Arrays

Array types in Titan have the form `{ t }`, where `t` is any Titan type
(including other array types, so `{ { integer } }` is the type for an array of
arrays of integers, for example.

You can create an empty array with the `{}` expression: Titan will try to guess
the type of this array from the context where you are creating it.
For example, if you are assigning the new array to an array-typed variable, the
array will have the same type of the variable.
If you are passing the array as an argument to a function that expects an
array-type parameter, the new array will have the same type as the parameter.
If you are declaring a new variable with an explicit array type declaration,
the new array will have the type you declared.
The only time where no context is available is when you declaring a new
variable and you have not given a type to it; in that case the array will have
type `{ integer }`.

### Records

Records are nominal and should be declared in the top level, like the following
example.

    record Point
        x: float
        y: float
    end

    record Circle
        center: Point
        radius: float
    end

After the top level declaration, you may create records with the `.new`
constructor:

    local p = Point.new(1, 2)
    local c = Circle.new(p, 3.5)

You can access the fields with the dot operator:

    local a = p.x
    p.y = 2

## Modules

A Titan source file (with a `.titan` extension) is a *Titan module*. A Titan module
is made-up of *import statements*, *module variable declarations*, and *module function
declarations*. These can appear in any order, but the Titan compiler reorders
them so all import statements come first (in the order they appear), followed by
variable declarations (again in the order they appear), and finally by function
declarations, so an imported module can be used anywhere in a module,
a module variable can be used in any function as well as variable declarations
that follow it, and module functions can be used in any other function.

### `import` statements

An `import` statement references another module and lets the current
module use its exported module variables and functions. Its syntax
is:

    local <localname> = import "<modname>"

The module name `<modname>` is a name like `foo`, `foo.bar`, or `foo.bar.baz`.
The Titan compiler translates a module name into a file name by converting
all dots to path separators, and then appending `.titan`, so the above three
modules will correspond to `foo.titan`, `foo/bar.titan`, and `foo/bar/baz.titan`.
All paths are relative the the path where you are running `titanc`.

The `<localname>` can be any valid identifier, and will be the prefix for accessing
module variables and functions.

    -- in 'bar.titan'
    x = 42
    function bar(): integer
      return x * x
    end

    -- in 'foo.titan'
    local m = import "bar"
    function foo(x: integer): integer
      local y = m.bar()
      bar.x = bar.x + x
      return y
    end

In the above example, the module `foo.titan` imports `bar.titan` and
gives it the local name `m`. Module `foo` can access the exported variable `x`, as well
as call the exported function `bar`.

### Module variables

A variable declaration has the syntax:

    [local] <name> [: <type>] = <value>

A `local` variable is only visible inside the module it is defined. Variables that
are not local are *exported*. An exported variable is visible in modules that import
this module, and is also visible from Lua if you `require` the module.

The `<name>` can be any valid identifier. You cannot have two module variables with
the same name. The type is optional, and if not given will be inferred from the
initial value. The initial value can be any valid Titan expression, as long as it
only uses things that are visible (module variables declared prior to this one and
members of imported modules).

### Functions

A function declaration has the syntax:

    [local] function <name>([<params>])[: <rettype>]
        <body>
    end

A `local` function is only visible inside the module it is defined. Functions that
are not local are exported, and visible in modules that import this one, as well
as callable from Lua if you `require` the module.

As with variables, `<name>` can be any valid identifier, but it is an error to
declare two functions with the same name, or a function with the same name as
a module variable. The return type `<rettype>` is optional, and if not given it
is assumed that the function does not return anything or just returns `nil`.

Parameters are a comma-separated list of `<name>: <type>`. Two parameters cannot
have the same name. The body is a sequence of statements.

### The Complete Syntax of Titan

Here is the complete syntax of Titan in extended BNF. As usual in extended BNF, {A} means 0 or more As, and \[A\] means an optional A.

    program ::= {tlfunc | tlvar | tlrecord}

    tlfunc ::= [local] function Name '(' [parlist] ')'  ':' type block end

    tlvar ::= [local] Name [':' type] '=' Numeral

    tlrecord ::= record Name recordfields end

    parlist ::= Name ':' type {',' Name ':' type}

    type ::= integer | float | boolean | string | '{' type '}'

    recordfields ::= recordfield {recordfield}

    recordfield ::= Name ':' type

    block ::= {stat} [retstat]

    stat ::=  ';' |
        var '=' exp |
        functioncall |
        do block end |
        while exp do block end |
        repeat block until exp |
        if exp then block {elseif exp then block} [else block] end |
        for Name '=' exp ',' exp [',' exp] do block end |
        local name [':' type] '=' exp

    retstat ::= return exp [';']

    var ::=  Name | prefixexp '[' exp ']' | prefixexp '.' Name

    explist ::= exp {',' exp}

    exp ::= nil | false | true | Numeral | LiteralString |
        prefixexp | tableconstructor | exp binop exp | unop exp

    prefixexp ::= var | functioncall | '(' exp ')'

    functioncall ::= prefixexp args

    args ::= '(' [explist] ')' | tableconstructor | LiteralString

    tableconstructor ::= '{' [fieldlist] '}'

    fieldlist ::= exp {fieldsep exp} [fieldsep]

    fieldsep ::= ',' | ';'

    binop ::=  '+' | '-' | '*' | '/' | '//' | '^' | '%' |
        '&' | '~' | '|' | '>>' | '<<' | '..' |
        '<' | '<=' | '>' | '>=' | '==' | '~=' |
        and | or

    unop ::= '-' | not | '#' | '~'
