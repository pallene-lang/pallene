# Pallene Language Reference

Welcome to the Pallene reference manual. This is a work in progress, so if you
have any questions or suggestions, or if some point wasn't clear, please feel
free to ask questions through a Github issue.

## A brief overview of Pallene

Pallene is a statically-typed companion langage to Lua. Pallene functions can
be called from Lua and can call Lua functions. At a first glance, Pallene code
looks similar to Lua, but with type annotations.

Here is an example Pallene program for summing the elements in an array of
floating-point numbers. Note that type anotations are required for function
argument and return types but for local variable declarations Pallene can often
infer the types.

    function sum(xs:{float}): float
        local r = 0.0
        for i = 1, #xs do
            r = r + xs[i]
        end
    end

If we pass this `sum.pallene` file to the `pallenec` compiler, it will output a 
`sum.so` Lua extension module:


    $ ./pallenec sum.pallene


The `sum.so` file can be loaded from within Lua with `require`, as usual:

    $ ./lua/src/lua
    > sum = require "sum"
    > print(sum.sum({10.0, 20.0, 30.0}))

## The Pallene Type System

Pallene's type system includes the usual Lua primitive types (`nil`, `boolean`,
`float` and `integer`), as well as strings, arrays, functions, and records.

### Primitive types

Pallene's primitive types are the same as Lua's:

- `nil`
- `boolean`
- `integer`
- `float`

There is no automatic coercion between `integer` and `float`. For example,
`local x:float = 0` is a type error. You should use `0.0` instead.

### Strings

Pallene also has a `string` type, for Lua strings. The syntax for string
literals is the same as in Lua.

At the moment, the only supported operations for Pallene strings is
concatenation with the `..` operator and printing strings to stdout with
`io_write`.

### Arrays

Array types in Pallene have the form `{ t }`, where `t` is any Pallene type
(including other array types, so `{ { integer } }` is the type for an array of
arrays of integers, for example.

Pallene arrays are implemented as Lua tables, and Pallene also uses the same
syntax for array creation:

    local xs:{integer} = {10, 20, 30}

One important thing to know about array literals in Pallene is that they must be
acompanied by a type annotation. Pallene cannot infer their type otherwise

    -- This produces a compile-time error
    -- "missing type hint for array or record initializer"
    local xs = {10, 20, 30}

Reading from an "out of bounds" index produces a run-time type error instead of
returning `nil`.

### Functions

Function types in Pallene are created with the `->` type constructor. For
example, `(a, b) -> (c)` is the function type for a function that receives two
arguments (the first of type `a` and the second of type `b`) and returns a 
single value of type `c`. For function types that only receive one input
parameter or return a single value, the parentheses are optional. For example,
the following are all valid function types:

    int -> float
    (int, int) -> float
    string -> ()

The current Pallene implementation only supports functions with 0 or 1 return
values. We plan to support functions with two or more return values in a future
version.

The arrow type constructor is right associative. That is, `a -> b -> c` means
`a -> (b -> c)`.

A Pallene variable of function type may refer to either statically-typed Pallene
functions or to dynamically typed Lua functions. When calling a
dynamically-typed Lua function from Pallene, Pallene will check whether the Lua
function returned the correct types and number of arguments and it will raise a
run-time error if it does not receive what it expected.

### Records

Record types in Pallene are nominal and should be declared in the top level.
The following example declares a record `Point` with the fields `x` and `y`
which are floats.

    record Point
        x: float
        y: float
    end

Pallene points are created and used with a similar syntax to Lua:

    local p:Point = {x=10.0, y=20.0}
    local r2 = p.x*p.x + p.y*p.y

Pallene records are implemented as userdata, and are *not* Lua tables. You
cannot create a Lua table with an `x` and `y` field and pass it to a Pallene
function expecting a Point. That said, Pallene objects do carry a metatable
that allows you to still use the usual dot notation when acessing them from
Lua.

## Structure of a Pallene module

A Pallene module, consists of a sequence of type declarations, module-local
constants, and function defitions. They must appear in this order.

```
<type and record declarations>
<module-local variables>
<function definitions>
```

Module-local variables are currently restricted to primitive types and strings.
They must also be constants (never assigned to). These restrictions may be
lifted in a future version of Pallene.

The syntax for function definitions is described in the following section.

### Functions

A function declaration has the following syntax:

    [local] function <name>([<params>])[: <rettypes>]
        <body>
    end

A `local` function is only visible inside the module it is defined. Functions
that are not local are exported, and visible in modules that import this one,
as well as callable from Lua if you `require` the module.

As with variables, `<name>` can be any valid identifier, but it is a 
compile-time error to declare two functions with the same name, or a function
with the same name as a module variable. The return types `<rettypes>` are
optional, and if not given it is assumed that the function does not return
anything.

Parameters are a comma-separated list of `<name>: <type>`. Two parameters cannot
have the same name. The body is a sequence of statements.

Unlike Lua, Pallene function definitions are mutually recursive. A function
at the start of the function definition block is allowed to call other functions
further down the file. There is no need to provide a forward function
declaration.

## Expressions and Statements

Pallene uses the same set of operators and control-flow statements as Lua. The
only difference is that the type system is more restrictive:

* Logic operators (`not`, `and`, `or`) only operate on booleans
* The condition for `if`, `while` and `repeat` must be a boolean
* Relational operators (`==`, `<`, etc) must receive two arguments of the same
type.
* The arithmetic and concatenation operators don't automatically coerce between
numbers and strings.

## The Complete Syntax of Pallene

Here is the complete syntax of Pallene in extended BNF. As usual, {A} means 0 or
more As, and \[A\] means an optional A.

    program ::= {toplevelrecord} {toplevelvar} {toplevelfunc}

    toplevelrecord ::= record Name {recordfield} end
    recordfield ::= NAME ':' type [';']

    toplevelvar ::= [local] NAME [':' type] '=' exp

    toplevelfunc ::= [local] function NAME '(' [paramlists] ')'  [':' type] block end

    paramlist ::= NAME ':' type {',' NAME ':' type}

    type ::= nil | integer | float | boolean | string | '{' type '}' | NAME

    block ::= {statement} [returnstat]

    statement ::=  ';' |
        var '=' exp |
        function_call |
        do block end |
        while exp do block end |
        repeat block until exp |
        if exp then block {elseif exp then block} [else block] end |
        for NAME [':' type] '=' exp ',' exp [',' exp] do block end |
        local name [':' type] '=' exp

    returnstat ::= return exp [';']

    var ::=  NAME | exp '[' exp ']' | exp '.' Name

    exp ::= nil | false | true | NUMBER | STRING | initlist | exp as type |
        unop exp | exp binop exp | funccall | '(' exp ')' | exp '.' NAME

    funccall ::= exp funcargs

    funcargs ::= '(' [explist] ')' | initlist | STRING
    explist ::= exp {',' exp}

    initlist ::= '{' fieldlist '}'
    fieldlist ::= [ field {fieldsep field} [fieldsep] ]
    field ::= exp | NAME '=' exp
    fieldsep ::= ',' | ';'

    unop ::= '-' | not | '#' | '~'

    binop ::=  '+' | '-' | '*' | '/' | '//' | '^' | '%' |
        '&' | '~' | '|' | '>>' | '<<' | '..' |
        '<' | '<=' | '>' | '>=' | '==' | '~=' |
        and | or
