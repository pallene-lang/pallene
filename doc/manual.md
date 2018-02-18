# Titan Language Reference

## Types

### Basic Types

- `nil`
- `boolean`
- `integer`
- `float`
- `string`
- `value`

### Arrays

Array types in Titan have the form `{ t }`, where `t` is any Titan type
(including other array types, so `{ { integer } }` is the type for an array of
arrays of integers, for example.

You can create an empty array with the `{}` expression: Titan will try to infer
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

### Functions

Function types in Titan are created with the `->` type constructor. For
example, `(a, b) -> (c)` is the function type for a function that receives one
argument of type `a` and one of type `b` and returns a value of type `c`. For
function types that only receive one input parameter or return a single value,
the parentheses are optional. For example, `int -> string` is the type of
functions that map `int` to `string`. The `->` type constructor is right
associative. That is, `a -> b -> c` is equivalent to `a -> (b -> c)`, the type
of functions that receive an `a` and return a function that receives a `b` and
return a `c`.

A titan variable of function type may refer to either statically-typed Titan
functions or to dynamically typed Lua functions. When calling a
dynamically-typed Lua function from Titan, Titan will check whether the Lua
function returned the correct types and number of arguments and it will raise a
run-time error if it does not receive what it expected.

#### Limitations

In the current version of Titan, Titan functions can only return a single return
value and a run-time error is produced if a Lua function called from Titan returns
more than one return value. A future of version of Titan will implement multiple
return values for functions.

### Records

Records types in Titan are nominal and should be declared in the top level.
The following example declare a record `Point` with the fields `x` and `y`
which are floats.

    record Point
        x: float
        y: float
    end

You can create records with initializer lists or using the `new` constructor.
When using initializer lists, you must assign a value to each field of the
record.
The `Type.new()` constructor is automatically declared and receive a parameter
for each field in the order they were declared.
For instance, you could initialize an instance of the record `Point` with:
`{ x = 3, y = 5 }`, `{ y = 5, x = 3 }` or `Point.new(3, 5)`.
In all those cases, the field `x` will receive the value `3` and the field `y`,
`5`.
Like arrays constructors, Titan will try to locally infer the type of
initializer lists.

You can read and write from fields of a record instance using the dot operator
`instance.field`. For example, `local x = p.x` and `p.y = 7`.

### The `value` type

If you declare that something has type `value` than it can hold values of any
Titan type, as well as any value that comes from Lua. In particular, `{ value }`
is the type of arrays that can hold any value.

You can use an expression that evaluates to any type in a context that expects
something with type `value`, and this is always safe (it will never throw a
run-time error). For example, if variable `i` has type `integer` and variable
`v` has type `value` then the assignment `v = i` always succeeds. Likewise,
if `t` has type `{ value }` the assignment `t[1] = i` always succeeds.

You can also use an expression that has type `value` in most contexts that
expect something with another type, but this will generate a runtime check
that might fail. In our previous examples with `v`, `i`, and `t` the assignments
`i = v` and `i = t[1]` are also allowed, but are checked at runtime to see
if the value being assigned is really an integer (or a floating-point value
that can be safely converted to an integer).

Contexts where Titan lets you pretend a `value` has another type are right-hand
sides of assignments and declarations, arguments to function calls, the index
in array accesses, in the expressions that initialize the parameters of a numeric
`for` loop, and in boolean `and`/`or` where the other side has type `boolean`.

The automatic casts to and from `value` extend to coumpound types where parts of
them are `value`: you can use a `{ value }` in a context that expects a `{ float }`,
and vice-versa, and the same holds for function types such as `value -> integer`,
`integer -> value`, `integer -> integer`, and `value -> value`. Notice this does
**not** extend to record types, as they are nominal! The two following types
are not compatible:

    record PointF
        x: float
        y: float
    end
    
    record PointV
        x: value
        y: value
    end

The only operations that you can do on things with type `value` are to cast them
to some other type and to pass them along.

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
all dots to path separators, and then appending `.so`, for binary modules, or
`.titan`, for source modules, so the above three
modules will correspond to `foo.{so|titan}`, `foo/bar.{so|titan}`, and `foo/bar/baz.{so|titan}`.
The Titan compiler will recompile the module if its source is newer than its binary.

Binary modules are looked up in the *runtime search path*, a semicolon-separated list
of paths that defaults to `.;/usr/local/lib/titan/0.5`, but can be overriden with a
`TITAN_PATH_0_5` or `TITAN_PATH` environment variable. Source modules are looked in
the *source tree*, which defaults to the current working directory, but can be overriden
with a command-line option to the Titan compiler. Generated binaries are always saved
in the same path of the source.

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

    [local] function <name>([<params>])[: <rettypes>]
        <body>
    end

A `local` function is only visible inside the module it is defined. Functions that
are not local are exported, and visible in modules that import this one, as well
as callable from Lua if you `require` the module.

As with variables, `<name>` can be any valid identifier, but it is an compile-time
error to declare two functions with the same name, or a function with the same name as
a module variable. The return types `<rettypes>` are optional, and if not given it
is assumed that the function does not return anything or just returns `nil`. (Currently
only functions with a single return type are implemented)

Parameters are a comma-separated list of `<name>: <type>`. Two parameters cannot
have the same name. The body is a sequence of statements.

## Expressions

### Explicit casts (`exp as type`)

You can use an explicit cast to convert between any two allowable types. For the
current version of Titan, this means from `value` to any other type, from any
other type to `value`, from `integer` to `float`, from `float` to `integer`, 
from `integer` and `float` to `string`, and from any type to `boolean`.
Most of these cannot fail (but you might lose precision when converting from
`integer` to `float`). The exceptions are conversions from `value` to other
types except `boolean`, and from `float` to `integer`.

Casts from `float` to `integer` fail if it is not an integral value, and if
this value is outside the allowable range for integers. Casts from `value`
fail if the value does not have the target type, or cannot be converted to it.

## The Complete Syntax of Titan

Here is the complete syntax of Titan in extended BNF. As usual in extended BNF, {A} means 0 or more As, and \[A\] means an optional A.

    program ::= {tlfunc | tlvar | tlrecord | tlimport}

    tlfunc ::= [local] function Name '(' [parlist] ')'  ':' type block end

    tlvar ::= [local] Name [':' type] '=' Numeral

    tlrecord ::= record Name recordfields end

    tlimport ::= local Name '=' import LiteralString

    parlist ::= Name ':' type {',' Name ':' type}

    type ::= value | integer | float | boolean | string | '{' type '}'

    recordfields ::= recordfield {recordfield}

    recordfield ::= Name ':' type [';']

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
        prefixexp | tableconstructor | exp binop exp | unop exp |
        exp as type

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
